-------------------------------------------------2 week

--1
select 
    count(distinct case when air.model like '%Boeing%' then tf.ticket_no end) as boeing_passengers,
    count(distinct case when air.model like '%Airbus%' then tf.ticket_no end) as airbus_passengers,
    count(distinct tf.ticket_no) as total_passengers
from bookings.ticket_flights tf 
join bookings.flights f on tf.flight_id = f.flight_id
join bookings.aircrafts air on f.aircraft_code = air.aircraft_code;

--2

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

select passenger_id, passenger_name
from bookings.tickets t
where passenger_id like '%000';
---h1

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

