-------------------------------------------------2 week

--1
Коллеги, скиньте, пожалуйста, статистику в Excel по количеству пассажиров для Boeing и Airbus. Мне нужны не модели самолетов, а именно производители. 
У нас в базе нет информации по бренду производителя, но вы можете вытащить эти данные из наименования модели.
На выходе мне нужна таблица из 3 столбцов - количество пассажиров Boeing, количество пассажиров Airbus, общее количество пассажиров всех рейсов.
select 
    count(distinct case when air.model like '%Boeing%' then tf.ticket_no end) as boeing_passengers,
    count(distinct case when air.model like '%Airbus%' then tf.ticket_no end) as airbus_passengers,
    count(distinct tf.ticket_no) as total_passengers
from bookings.ticket_flights tf 
join bookings.flights f on tf.flight_id = f.flight_id
join bookings.aircrafts air on f.aircraft_code = air.aircraft_code;

--2
Коллеги, нужны числа из номера билетов, с 4 по 9 (т.е. для номера 0005432159776 это будет 543215), для пассажиров, которые вылетали из аэропорта Мирный бизнес классом. 
В выгрузке прошу предоставить табличку с номером билета, числами с 4 по 9 билета и аэропортом вылета
select 
    t.ticket_no, substr(t.ticket_no, 4, 6) as ticket_digits,
    air.city as departure_city
from bookings.tickets t
join bookings.ticket_flights tf on t.ticket_no = tf.ticket_no 
join bookings.flights f on tf.flight_id = f.flight_id
join bookings.airports air on f.departure_airport = air.airport_code
where 1=1
	and air.city = 'Мирный'
    and tf.fare_conditions = 'Business';

--3
Коллеги, посмотрите, пожалуйста, сколько человек летало комфорт классом осенью 2016 года по месяцам, даты берите по плановым вылетам
select
    DATE_TRUNC('month', f.scheduled_departure)::date AS month,
    COUNT(distinct tf.ticket_no) AS passenger_count
from bookings.ticket_flights tf
join bookings.flights f on tf.flight_id = f.flight_id
where 1=1
  and tf.fare_conditions = 'Comfort'
  and f.scheduled_departure >= DATE '2016-09-01'
  and f.scheduled_departure < DATE '2016-12-01'
group by month
order by month;

--4
**Описание задачи:**

Коллеги, мы хотим разыграть автомобиль среди пассажиров, но из розыгрыша нужно исключить некоторых пользователей, имеющих "специальный статус". В базе это пользователи, у которых последние 3 значения в id 000. Дайте, пожалуйста, айдишники и имена этих пользователей

**Definition of Done:**

- В комментарии к задаче приложена выгрузка в Excel согласно описанию задачи
select passenger_id, passenger_name
from bookings.tickets t
where passenger_id like '%000';
---h1
Коллеги, к нам поступили претензии о том, что наши билеты комфорт класса в 3 раза дороже, чем бизнес. Найти такие билеты не можем.

Могли бы вы, пожалуйста, изучить данные и если обнаружите такой кейс, где комфорт в 3 раза выше бизнеса, выгрузить id-шники билетов и рейсов (ticket_no и flight_id) и их цену.

По исследованию - хотелось бы понять распределение цен по полетам (flight_id). Нас интересуют меры центральной тенденции и меры изменчивости по разным классам (бизнес, эконом, комфорт)

Результат просим предоставить в одном Excel файле, где на первой странице - исследование, на второй - idшники бизнеса, который ниже минимальной цены комфорта (если такие есть)


--
select tf.ticket_no, tf.flight_id, tf.amount 
from bookings.ticket_flights tf
join (SELECT flight_id, MIN(amount) AS min_business_price
      FROM bookings.ticket_flights tf
      WHERE tf.fare_conditions = 'Business'
      GROUP BY flight_id
) biz on biz.flight_id=tf.flight_id
where 1=1
	and tf.fare_conditions = 'Comfort'
	and tf.amount >= 3 * biz.min_business_price
	
--

select 
    tf.fare_conditions,
    tf.flight_id,
    count(*) as count,
    round(AVG(tf.amount), 2) as amount_av,
    percentile_cont(0.5) within group (order by tf.amount) as amount_median,
    mode() within group (order by tf.amount) as amount_mode,
    round(stddev(tf.amount), 2) as amount_stddev,
    min(tf.amount) as amount_min,
    max(tf.amount) as amount_max
from bookings.ticket_flights tf
group by tf.fare_conditions, tf.flight_id
order by tf.flight_id, tf.fare_conditions;
-------------------------------------------------3 week

---1
Коллеги, прошу выгрузить производителей самолетов, которые мы выделяли на прошлой неделе, но у которых range выше среднего по производителю.
Нам нужно выбрать модели, наиболее приспособленные для длительных рейсов.
В выгрузке прошу приложить табличку с наименованием модели, производителем, значением range и средним range по производителю.
Производителей можно разделить на Boeing, Airbus и другие.

WITH aircrafts_labeled AS (
    SELECT *,
        CASE 
            WHEN split_part(model, ' ', 1) IN ('Boeing', 'Airbus') THEN split_part(model, ' ', 1)
            ELSE 'Другие'
        END AS group_name
    FROM bookings.aircrafts
),
avg_ranges AS (
    SELECT group_name, AVG(range) AS avg_range
    FROM aircrafts_labeled
    GROUP BY group_name
)
SELECT 
    a.model, 
    a.group_name AS model_name,
    a.range, 
    ROUND(ar.avg_range) AS avg_range
FROM aircrafts_labeled a
JOIN avg_ranges ar ON a.group_name = ar.group_name
WHERE a.range > ar.avg_range;

---2
Коллеги, на прошлой неделе получили от вас исследование по статистическим метрикам на разных классах полетов.
Теперь нам нужно выбрать билеты класса Economy, у которых стоимость выше, чем 0.95 перцентиль цены комфорта.
В таблице нам нужен номер билета, id рейса (который flight_id), цена, и цена 95 перцентиля комфорта

with comfort_p95 as (
    select percentile_cont(0.95) within group (order by amount) as p95
    from bookings.ticket_flights
    where fare_conditions = 'Comfort'
)
select 
    tf.ticket_no,
    tf.flight_id,
    tf.amount, 
    cp.p95
from bookings.ticket_flights tf
join comfort_p95 cp on true
where 1=1
	and tf.fare_conditions = 'Economy'
    and tf.amount > (select p95 from comfort_p95)
order by tf.flight_id, tf.fare_conditions;

------------------------------------------------------------4 week

---1
Добрый день! Коллеги, необходимо выгрузить номера билетов и номера полетов (ticket_no & flight_id), 
у которых общая стоимость входит в ТОП-3. При этом нас интересует как общая стоимость билета, 
так и стоимость каждой отдельной “пересадки”, т.е. таблица должна содержать для топ-3 билетов по цене: 
1. Номер билета
2. Номер полета (пересадки)
3. Цену полета (пересадки)
4. Общую цену билета

WITH cte_1 AS (
  SELECT 
    ticket_no,
    flight_id,
    amount, fare_conditions,
    ROW_NUMBER() OVER (PARTITION BY ticket_no ORDER BY flight_id) AS segment_order
  FROM bookings.ticket_flights
  WHERE ticket_no IN (SELECT ticket_no FROM bookings.ticket_flights GROUP BY ticket_no HAVING COUNT(*) > 1)
),
cte_1_0 AS (
  SELECT 
    ticket_no, 
    SUM(amount) AS total_amount
  FROM bookings.ticket_flights
  GROUP BY ticket_no
  ORDER BY total_amount DESC
  LIMIT 3
)

SELECT 
  cte_1.ticket_no, cte_1.flight_id, cte_1.fare_conditions,
  cte_1.amount AS _amount,
  cte_1_0.total_amount AS total_amount
FROM cte_1
JOIN cte_1_0 ON cte_1.ticket_no = cte_1_0.ticket_no 
ORDER BY cte_1_0.total_amount DESC, cte_1.ticket_no, cte_1.flight_id;


---2

Добрый день! Коллеги, необходимо выгрузить билеты, 
у которых 5 имеется flight_id. 
В итоговой таблице нужно видеть id билета, 
id полета (пересадки) и стоимость каждого flight.



with cte_2 as (
	select ticket_no
    FROM bookings.ticket_flights 
    GROUP BY ticket_no
    HAVING COUNT(flight_id) = 5
)

select tf.ticket_no, tf.flight_id, tf.amount 
from bookings.ticket_flights tf
join cte_2 on tf.ticket_no=cte_2.ticket_no
order by tf.ticket_no, tf.flight_id

---3

Доброго времени суток! 

Необходимо предоставить выгрузку билетов, у которых есть три пересадки и "класс" 
места для первого маршрута - Эконом.

Хотим детальнее изучить такие рейсы. 

В выгрузке необходимо предоставить:

1. номер тикета
2. номер полета
3. стоимость полета
4. класс полета
5. класс первого полета в рамках тикета

with cte_3 as (
	select ticket_no
	from bookings.ticket_flights 
	group by ticket_no
	having count(flight_id)=4
)
,
cte_3_0 as (
	select ticket_no, fare_conditions as first_fare_class
	from (
		select ticket_no, flight_id, fare_conditions, 
		row_number() over (partition by ticket_no order by flight_id) as rn
		from bookings.ticket_flights 
	) 
	where rn = 1
)

select tf.ticket_no, tf.flight_id, tf.amount, tf.fare_conditions, cte_3_0.first_fare_class
from bookings.ticket_flights tf
join cte_3 on tf.ticket_no=cte_3.ticket_no
join cte_3_0 on tf.ticket_no=cte_3_0.ticket_no
where cte_3_0.first_fare_class = 'Economy'
order by tf.ticket_no, tf.flight_id
---4
Коллеги, нам нужно срочно получить информацию о ТОП-3 билетах по количеству пересадок (flight_id)
и общей цене тикета, в которых хотя бы 1 раз был перелет бизнес-классом.
В результатах выгрузки представьте номер тикета, количество пересадок, 
сумму тикета и количество пересадок бизнесс-классом внутри тикета

with cte_4 as (
	select tf.ticket_no, COUNT(*) OVER (PARTITION BY flight_id) AS flight_count
	from bookings.ticket_flights tf
)
,
cte_4_0 as (
	SELECT DISTINCT
    tf.ticket_no,
    --SUM(tf.amount) OVER (PARTITION BY tf.ticket_no) AS total_ticket_amount
    COUNT(*) OVER (PARTITION BY flight_id) as business_flight_count
	FROM bookings.ticket_flights tf
	WHERE tf.ticket_no IN (
    	SELECT ticket_no
    	FROM bookings.ticket_flights
    	WHERE fare_conditions = 'Business'
	)
	ORDER BY tf.ticket_no
)
select tf.ticket_no, cte_4.flight_count, tf.amount, cte_4_0.business_flight_count from bookings.ticket_flights tf
join cte_4 on tf.ticket_no=cte_4.ticket_no
join cte_4_0 on tf.ticket_no=cte_4_0.ticket_no
limit 3

--
WITH ticket_summary AS (
    SELECT
        tf.ticket_no,
        COUNT(*) AS total_flights,
        SUM(tf.amount) AS total_amount,
        SUM(CASE WHEN tf.fare_conditions = 'Business' THEN 1 ELSE 0 END) AS business_flights
    FROM bookings.ticket_flights tf
    GROUP BY tf.ticket_no
),
business_tickets AS (
    SELECT *
    FROM ticket_summary
    WHERE business_flights > 0
)
SELECT *
FROM business_tickets
ORDER BY total_flights DESC, total_amount DESC
LIMIT 3;

--5
Коллеги, здравствуйте! 
Есть следующий запрос - хотим посмотреть количество билетов и детализацию по ним,
у которых есть 1 пересадка (больше 1 пока не нужно), 
и при этом цена первой и второй части билета одинаковая.
Выгрузка нужна для дальнейшего анализа этих билетов на нашей стороне. 
Хотим изучить, сможем ли мы снизить цену второго маршрута и за счет этого 
добиться общего снижения цены билета. 

В выгрузке нужны столбцы: 

1. номер тикета
2. номер полета
3. класс полета
4. стоимость полета
5. стоимость тикета
6. порядковый номер полета (берите по flight_id)


WITH segments AS (
  SELECT 
    ticket_no,
    flight_id,
    amount, fare_conditions,
    ROW_NUMBER() OVER (PARTITION BY ticket_no ORDER BY flight_id) AS segment_order
  FROM bookings.ticket_flights
  WHERE ticket_no IN (SELECT ticket_no FROM bookings.ticket_flights GROUP BY ticket_no HAVING COUNT(*) = 2)
),

ticket_sums AS (
  SELECT 
    ticket_no, 
    SUM(amount) AS total_amount
  FROM bookings.ticket_flights
  GROUP BY ticket_no
)

SELECT 
  s1.ticket_no, s1.flight_id, s1.fare_conditions,
  s1.amount AS first_amount,
  s2.amount AS second_amount,
  ts.total_amount
FROM segments s1
JOIN segments s2 ON s1.ticket_no = s2.ticket_no AND s1.segment_order = 1 AND s2.segment_order = 2
JOIN ticket_sums ts ON s1.ticket_no = ts.ticket_no
WHERE s1.amount = s2.amount

with tf as ( 
	select
		ticket_no,
    	flight_id,
    	amount, 
    	fare_conditions,
    	ROW_NUMBER() OVER (PARTITION BY ticket_no ORDER BY flight_id) AS segment_order,
    	SUM(amount) AS total_amount
	FROM bookings.ticket_flights
	WHERE 1=1
		and ticket_no IN (SELECT ticket_no FROM bookings.ticket_flights GROUP BY ticket_no HAVING COUNT(*) = 2)
	group by ticket_no, flight_id, amount, fare_conditions
),
segments AS (
    SELECT
        ticket_no,
        MAX(CASE WHEN segment_order = 1 THEN amount END) AS amount_1,
        MAX(CASE WHEN segment_order = 2 THEN amount END) AS amount_2,
        SUM(amount) AS total_amount
    FROM tf
    GROUP BY ticket_no
    HAVING MAX(CASE WHEN segment_order = 1 THEN amount END) = MAX(CASE WHEN segment_order = 2 THEN amount END)
)
SELECT
    tf.ticket_no,
    tf.flight_id,
    tf.fare_conditions,
    tf.amount,
    s.total_amount,
    tf.segment_order
FROM tf
JOIN segments s ON tf.ticket_no = s.ticket_no
ORDER BY tf.ticket_no, tf.segment_order;
---h1
Коллеги, мы хотим изучить, как растет полная стоимость билетов в 
зависимости от количества пересадок. Для первой итерации мы хотели 
бы получить накопительную сумму для ТОП-10 билетов по их общей стоимости.

В выгрузке просим предоставить детальную информацию:

1. номер тикета
2. номер полета
3. класс полета
4. цена полета
5. общая цена билета
6. стоимость с накоплением 

По порядку накопления можете ориентироваться на flight_id

WITH ticket_segments AS (
  SELECT 
    ticket_no,
    flight_id,
    amount,
    fare_conditions,
    ROW_NUMBER() OVER (PARTITION BY ticket_no ORDER BY flight_id) AS segment_order
  FROM bookings.ticket_flights
  WHERE ticket_no IN (
    SELECT ticket_no
    FROM bookings.ticket_flights
    GROUP BY ticket_no
    HAVING COUNT(*) > 1
  )
),
top_tickets AS (
  SELECT 
    ticket_no,
    SUM(amount) AS total_amount
  FROM bookings.ticket_flights
  GROUP BY ticket_no
  ORDER BY total_amount DESC
  LIMIT 10
),
detailed AS (
  SELECT 
    ts.ticket_no,
    ts.flight_id,
    ts.fare_conditions,
    ts.amount,
    tt.total_amount,
    SUM(ts.amount) OVER (PARTITION BY ts.ticket_no ORDER BY ts.flight_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_amount
  FROM ticket_segments ts
  JOIN top_tickets tt ON ts.ticket_no = tt.ticket_no
)

SELECT 
  ticket_no,
  flight_id,
  fare_conditions,
  amount,
  total_amount,
  cumulative_amount
FROM detailed
ORDER BY total_amount DESC, ticket_no, flight_id;

