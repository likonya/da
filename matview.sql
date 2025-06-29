create materialized view passengers_info_mv as
with ticket_stats as(
	SELECT
	    passenger_id,
	    COUNT(*) AS total_tickets,
	    SUM(ticket_total_amount) AS total_tickets_amount,
	    AVG(ticket_total_amount) AS avg_tickets_amount
	from (
		SELECT
	        t.ticket_no,
	        t.passenger_id,
	        SUM(tf.amount) AS ticket_total_amount
	    FROM bookings.tickets t
	    JOIN bookings.ticket_flights tf ON tf.ticket_no = t.ticket_no
	    GROUP BY t.ticket_no, t.passenger_id
	 ) individual_tickets
	 GROUP BY passenger_id
),
flight_counts as(
    SELECT
        t.passenger_id,
        AVG(flight_per_ticket.count_flights) AS average_flights
    FROM bookings.tickets t
    JOIN (
        SELECT ticket_no, COUNT(DISTINCT flight_id) AS count_flights
        FROM bookings.ticket_flights
        GROUP BY ticket_no
    ) AS flight_per_ticket ON flight_per_ticket.ticket_no = t.ticket_no
    GROUP BY t.passenger_id
),
--more_often_city_from as (
--	select t.passenger_id, f.departure_airport, a.city as most_common_city_from,
--			COUNT(*) AS count_city_from,
--	        ROW_NUMBER() OVER (PARTITION BY t.passenger_id ORDER BY COUNT(*) DESC) AS rn
--	from bookings.tickets t 
--	join bookings.ticket_flights tf on tf.ticket_no=t.ticket_no
--	join bookings.flights f on f.flight_id=tf.flight_id
--	join bookings.airports a on a.airport_code = f.departure_airport
--	group by t.passenger_id, f.departure_airport, a.city
--),
--more_often_city_to as(
--	select t.passenger_id, f.arrival_airport, a.city as most_common_city_to,
--			COUNT(*) AS count_city_to,
--	        ROW_NUMBER() OVER (PARTITION BY t.passenger_id ORDER BY COUNT(*) DESC) AS rn
--	from bookings.tickets t 
--	join bookings.ticket_flights tf on tf.ticket_no=t.ticket_no
--	join bookings.flights f on f.flight_id=tf.flight_id
--	join bookings.airports a on a.airport_code = f.arrival_airport
--	group by t.passenger_id, f.arrival_airport, a.city
--),
more_often_city_from AS (
    SELECT 
        passenger_id,
        CASE 
            WHEN COUNT(*) FILTER (WHERE rank = 1) = 1 THEN 
                MAX(CASE WHEN rank = 1 THEN city END)
            ELSE NULL
        END AS most_common_city_from
    FROM (
        SELECT 
            t.passenger_id,
            a.city AS city,
            COUNT(*) AS city_count,
            DENSE_RANK() OVER (PARTITION BY t.passenger_id ORDER BY COUNT(*) DESC) AS rank
        FROM bookings.tickets t
        JOIN bookings.ticket_flights tf ON tf.ticket_no = t.ticket_no
        JOIN bookings.flights f ON f.flight_id = tf.flight_id
        JOIN bookings.airports a ON a.airport_code = f.departure_airport
        GROUP BY t.passenger_id, a.city
    ) ranked
    GROUP BY passenger_id
),
more_often_city_to AS (
    SELECT 
        passenger_id,
        CASE 
            WHEN COUNT(*) FILTER (WHERE rank = 1) = 1 THEN 
                MAX(CASE WHEN rank = 1 THEN city END)
            ELSE NULL
        END AS most_common_city_to
    FROM (
        SELECT 
            t.passenger_id,
            a.city AS city,
            COUNT(*) AS city_count,
            DENSE_RANK() OVER (PARTITION BY t.passenger_id ORDER BY COUNT(*) DESC) AS rank
        FROM bookings.tickets t
        JOIN bookings.ticket_flights tf ON tf.ticket_no = t.ticket_no
        JOIN bookings.flights f ON f.flight_id = tf.flight_id
        JOIN bookings.airports a ON a.airport_code = f.arrival_airport
        GROUP BY t.passenger_id, a.city
    ) ranked
    GROUP BY passenger_id
),
preffered_airport as(
	select 
		passenger_id,
		case 
			when COUNT(*) FILTER (WHERE rank = 1) = 1 THEN 
                MAX(CASE WHEN rank = 1 THEN airport_code END)
		end as preffered_airport
	from (
		select
			passenger_id,
			airport_code,
			count(*) as airport_count,
			DENSE_RANK() OVER (PARTITION BY passenger_id ORDER BY COUNT(*) DESC) AS rank
		from (
			select 
				t.passenger_id,
				f.departure_airport as airport_code
			from bookings.tickets t
			join bookings.ticket_flights tf on tf.ticket_no = t.ticket_no
			join bookings.flights f on f.flight_id = tf.flight_id
			
			union all
			
			select 
				t.passenger_id,
				f.arrival_airport as airport_code
			from bookings.tickets t
			join bookings.ticket_flights tf on tf.ticket_no = t.ticket_no
			join bookings.flights f on f.flight_id = tf.flight_id
		) as all_airports 
		group by passenger_id, airport_code
	) as ranked_airports	
	group by passenger_id
),
preffered_seat as (
	select
		passenger_id,
		case 
			when COUNT(*) FILTER (WHERE rank = 1) = 1 THEN 
       	       MAX(CASE WHEN rank = 1 THEN seat_no END)
		end as preffered_seat
	from (
		select
			passenger_id,
			seat_no,
			count(*) as seat_count,
			DENSE_RANK() OVER (PARTITION BY passenger_id ORDER BY COUNT(*) DESC) AS rank
		from bookings.tickets t
		join bookings.ticket_flights tf on t.ticket_no=tf.ticket_no
		join bookings.boarding_passes bs on bs.ticket_no=tf.ticket_no and bs.flight_id = tf.flight_id
		group by t.passenger_id, bs.seat_no
	) ranked_seats
	group by passenger_id
),
preffered_conditions as (
	select passenger_id,
		case 
			when COUNT(*) FILTER (WHERE rank = 1) = 1 THEN 
       	       MAX(CASE WHEN rank = 1 THEN fare_conditions END)
		end as preffered_conditions
	from (
		select
			passenger_id,
			fare_conditions,
			count(*) as count_condition,
			DENSE_RANK() OVER (PARTITION BY passenger_id ORDER BY COUNT(*) DESC) AS rank
		from bookings.ticket_flights tf
		join bookings.tickets t on t.ticket_no=tf.ticket_no
		group by t.passenger_id, tf.fare_conditions
	) ranked_conditions
	group by passenger_id
),
phone_email_name as (
	select 
		passenger_id,
		passenger_name,
		contact_data ->> 'email' AS email,
    	contact_data ->> 'phone' AS phone
	from bookings.tickets t
	group by passenger_id, passenger_name, contact_data
),
total_range as (
	select 
		passenger_id,
		SUM(air.range) AS total_range
	from bookings.tickets t
	join bookings.ticket_flights tf on t.ticket_no=tf.ticket_no
	JOIN bookings.flights f ON f.flight_id = tf.flight_id
    join bookings.aircrafts air on f.aircraft_code=air.aircraft_code
    group by passenger_id
)

select 
    ts.passenger_id,
    ts.total_tickets,
    ts.total_tickets_amount,
    ts.avg_tickets_amount,
    fc.average_flights,
    mof.most_common_city_from,
    --mof.count_city_from,
    mot.most_common_city_to,
    --mot.count_city_to
    pa.preffered_airport,
    ps.preffered_seat,
    pc.preffered_conditions,
    pen.passenger_name,
    pen.email,
    pen.phone,
    tr.total_range
from ticket_stats ts
left join flight_counts fc on ts.passenger_id = fc.passenger_id
left join more_often_city_from mof on ts.passenger_id = mof.passenger_id
left join more_often_city_to mot on ts.passenger_id = mot.passenger_id
left join preffered_airport pa on ts.passenger_id = pa.passenger_id
left join preffered_seat ps on ts.passenger_id = ps.passenger_id
left join preffered_conditions pc on ts.passenger_id = pc.passenger_id
left join phone_email_name pen on ts.passenger_id = pen.passenger_id
left join total_range tr on ts.passenger_id = tr.passenger_id

--DROP MATERIALIZED VIEW IF EXISTS passengers_info_mv
select * from passengers_info_mv