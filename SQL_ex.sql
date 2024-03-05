-- Only orders with the final status DeliveredStatus can be considered as an order with a bill. 

WITH users AS (
  SELECT id,
		DATE_PART('Day', CURRENT_TIMESTAMP - signed_up_time) as sign_up_days -- Evaluation of the number of days since the sign up (timestamp)
	FROM users
 ),

OrderRanking AS (
  SELECT
      user_id,
      creation_time,
      RANK() OVER (PARTITION BY user_id ORDER BY creation_time DESC) AS order_rank -- Ranking of the orders (descending) to find the last and second last order
  FROM orders
  WHERE
        final_status = 'DeliveredStatus' -- Assuming we consider only delivered orders
),

OrderCounts AS (
    SELECT
        user_id,
        store_id,
        SUM(case when final_status = 'DeliveredStatus' 	THEN 1 ELSE 0 END) 		AS order_by_store_cnt,
  		SUM(case when final_status != 'DeliveredStatus' THEN 1 ELSE 0 END) 		AS cancelled_order_by_store_cnt,
  		SUM(case when final_status = 'DeliveredStatus' 	THEN total_price END) 	AS total_price, -- Only delivered orders are taken into account,
        MAX(case when final_status = 'DeliveredStatus' 	THEN creation_time END) AS latest_order_time --Last delivered order by store. If the status is cancelled, we do not consider that order

    FROM
        orders
    GROUP BY
        user_id, 
  		store_id
),
RankedStores AS (
    SELECT
        user_id,
        store_id,
        order_by_store_cnt,
        latest_order_time,
  		SUM(order_by_store_cnt) OVER (PARTITION BY user_id) 										AS total_order_nbr,
  		SUM(cancelled_order_by_store_cnt) OVER (PARTITION BY user_id) 								AS total_cancelled_order_cnt,
  		SUM(total_price) OVER (PARTITION BY user_id) 												AS total_eur,
        RANK() OVER (PARTITION BY user_id ORDER BY order_by_store_cnt DESC, latest_order_time DESC) AS rank -- Ranking fo stores by max rank and latest order time desc to find favorite restaurant
    FROM
        OrderCounts
)
SELECT 
		A.user_id,
		D.sign_up_days,
        total_order_nbr,
        --total_eur as total_eur,
		total_eur/total_order_nbr AS avg_order_eur,
        E.name as Favorite_store_name,
        round(total_order_nbr/(total_cancelled_order_cnt+total_order_nbr)*100,2) AS delivered_order_pct,
        B.creation_time as last_order_dt,
        --C.creation_time as second_last_order,
        DATE_PART('Day', B.creation_time - C.creation_time ) as time_between_last_two_orders_days, -- Base on timestamp
        CAST(B.creation_time AS date) - CAST(C.creation_time AS date) as time_between_last_two_orders_days_BIS -- Base only on the date
		
FROM RankedStores A

left JOIN OrderRanking B
ON A.user_id = B.user_id
and B.order_rank = 1

left JOIN OrderRanking C
ON A.user_id = C.user_id
and C.order_rank = 2

LEFT JOIN users D
ON A.user_id = D.id

LEFT JOIN stores E
ON A.store_id = E.id

WHERE
    rank = 1
    and total_order_nbr >=5;
