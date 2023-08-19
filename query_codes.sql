

--1.Import the dataset and do usual exploratory analysis steps like checking the structure & characteristics of the dataset:
# 1.Data type of all columns in the "customers" table.
SELECT
  column_name,
  data_type
FROM
  `target_buisness_case.INFORMATION_SCHEMA.COLUMNS`
WHERE
  table_name = 'customers';

# 2.Get the time range between which the orders were placed.

with cte as
(select min(order_purchase_timestamp) as min_order_placing_timestamp,
max(order_purchase_timestamp) max_order_placing_timestamp
from
`target_buisness_case.orders`)
select *, date_diff(cte.max_order_placing_timestamp,cte.min_order_placing_timestamp,day) Diff_of_dates
from cte;


# 3.Count the Cities & States of customers who ordered during the given period.

with cte as
(select *, min(order_purchase_timestamp ) over() as min_order_placing_timestamp,
max(order_purchase_timestamp) over() max_order_placing_timestamp
from `target_buisness_case.orders` o
left join `target_buisness_case.customers` c
on o.customer_id=c.customer_id)

select count(distinct customer_city) as customer_city_count ,
count(distinct customer_state)as customer_state_count,
from cte
where cte.order_purchase_timestamp between min_order_placing_timestamp and max_order_placing_timestamp ;

------------------------------------------------------------------------------------------------------------
--2.In-depth Exploration:
# 1.Is there a growing trend in the no. of orders placed over the past years?

with cte2 as
(with cte1 as
(with cte as
(SELECT *,
EXTRACT(year FROM o.order_purchase_timestamp)  as order_year,
EXTRACT(month FROM o.order_purchase_timestamp)  as order_month
from `target_buisness_case.orders` o)

select cte.order_year,cte.order_month,count( distinct order_id) as order_count
from cte
group by cte.order_year,cte.order_month
)
select cte1.order_year,cte1.order_month,cte1.order_count,
lag(cte1.order_count) over(order by cte1.order_year,cte1.order_month) as prev_order_count
from cte1
order by cte1.order_year,cte1.order_month)
select cte2.order_year,cte2.order_month,cte2.order_count,
round(((cte2.order_count-cte2.prev_order_count)/cte2.prev_order_count)*100) as Growth_of_orders
from cte2
;

# 2.Can we see some kind of monthly seasonality in terms of the no. of orders being placed?
SELECT *
FROM
(SELECT
  EXTRACT(YEAR FROM order_purchase_timestamp)AS order_year,
  EXTRACT(MONTH FROM order_purchase_timestamp) AS order_month,
  COUNT(distinct order_id) AS num_orders
FROM
 `target_buisness_case.orders` 
GROUP BY
  order_year, order_month
HAVING order_year=2016
ORDER BY
  order_year, order_month) tbl1
  FULL OUTER JOIN
  (SELECT
  EXTRACT(YEAR FROM order_purchase_timestamp)AS order_year,
  EXTRACT(MONTH FROM order_purchase_timestamp) AS order_month,
  COUNT(distinct order_id) AS num_orders
FROM
 `target_buisness_case.orders` 
GROUP BY
  order_year, order_month

HAVING order_year=2017
) tbl2
  using(order_month)
 FULL OUTER JOIN
  (SELECT
  EXTRACT(YEAR FROM order_purchase_timestamp)AS order_year,
  EXTRACT(MONTH FROM order_purchase_timestamp) AS order_month,
  COUNT(distinct order_id) AS num_orders
FROM
 `target_buisness_case.orders` 
GROUP BY
  order_year, order_month
HAVING order_year=2018
) tbl3
  using(order_month)

  ORDER BY
  order_month;

   #do self join fror comparison

#3.During what time of the day, do the Brazilian customers mostly place their orders? (Dawn, Morning, Afternoon or Night)
#0-6 hrs : Dawn| 7-12 hrs : Mornings |13-18 hrs : Afternoon || 19-23 hrs : Night
with cte as
(select *,
case when (EXTRACT(hour FROM order_purchase_timestamp)-3)>=0  #FOR CALCULATION OF LOCAL TIME FROM UTC
then (EXTRACT(hour FROM order_purchase_timestamp)-3)
else 24+(Extract(hour FROM order_purchase_timestamp)-3)
end as Brazilian_time
from `target_buisness_case.orders`)
select count(distinct order_id) as order_count,
case when Brazilian_time between 0 and 6 then 'Dawn'
 when Brazilian_time between 7 and 12 then 'Morning'
 when Brazilian_time between 13 and 18 then 'Afternoon'
else 'Night'
end as time_of_the_day
from cte
group by time_of_the_day
order by order_count desc;

--- 3.Evolution of E-commerce orders in the Brazil region:
#1.Get the month on month no. of orders placed in each state.

select c.customer_state as State,
extract (year from o.order_purchase_timestamp) as Year,
extract(month from o.order_purchase_timestamp) as Month,

count(distinct o.order_id) as No_of_orders
from `target_buisness_case.orders` o
join
`target_buisness_case.customers` c
on o.customer_id=c.customer_id
group by c.customer_state,Year,month
order by c.customer_state,Year,month;

# 2.How are the customers distributed across all the states?
with cte as
(select customer_state,count(distinct customer_id) as No_of_customers
from `target_buisness_case.customers`
group by customer_state
)
select  *, round((cte.No_of_customers/(SELECT sum(No_of_customers) from cte))*100,2) as percentage_of_customers
from cte
order by No_of_customers desc;

--- 4.Impact on Economy: Analyze the money movement by e-commerce by looking at order prices, freight and others.
# 1.Get the % increase in the cost of orders from year 2017 to 2018 (include months between Jan to Aug only).
with cte2 as
(with cte1 as
(with cte as(
select extract(year from o.order_purchase_timestamp) as order_year,
extract(month from o.order_purchase_timestamp) as order_month,
round(sum(p.payment_value),2) as cost_of_order
from `target_buisness_case.payments` p
join
 `target_buisness_case.orders` o
 on p.order_id=o.order_id
 group by order_year,order_month
 having order_month between 1 and 8 #include months between Jan to Aug only
 order by order_year,order_month)
 select order_year,round(sum(cost_of_order),2) as cost_order_per_year
 from cte
 group by order_year
 order by order_year)
 select order_year,cte1.cost_order_per_year, lag(cte1.cost_order_per_year) over(order by order_year) as prev_cost
 from cte1)
 select order_year,cte2.cost_order_per_year, round(((cost_order_per_year - prev_cost)/prev_cost)*100,2) as percentage_increase_of_cost
 from cte2
 order by order_year;
 

# 2.Calculate the Total & Average value of order price for each state.

select c.customer_state as State, ROUND(sum(oi.price),2) as Total_price,
ROUND(avg(oi.price),2)as Average_price
from `target_buisness_case.order_items` oi
join
`target_buisness_case.orders` o
on o.order_id=oi.order_id
join `target_buisness_case.customers` c
on o.customer_id=c.customer_id
group by c.customer_state
order by Average_price DESC
;

# 3.Calculate the Total & Average value of order freight for each state.

select c.customer_state as State, ROUND(sum(oi.freight_value),2) as Total_freight_value,
ROUND(avg(oi.freight_value),2)as Average_freight_value
from `target_buisness_case.order_items` oi
join
`target_buisness_case.orders` o
on o.order_id=oi.order_id
join `target_buisness_case.customers` c
on o.customer_id=c.customer_id
group by c.customer_state
order by Average_freight_value desc
;

----V. Analysis based on sales, freight and delivery time.
# A. Find the no. of days taken to deliver each order from the order’s purchase date as delivery time.
#Also, calculate the difference (in days) between the estimated & actual delivery date of an order.(Do this in a single query.)

select order_id,customer_id,
date_diff(order_delivered_customer_date,order_purchase_timestamp,day) as time_to_deliver,
date_diff(order_delivered_customer_date,order_estimated_delivery_date,day) as diff_estimated_delivery
from `target_buisness_case.orders`
where order_status='delivered' AND date_diff(order_delivered_customer_date,order_purchase_timestamp,day) IS NOT NULL
order by diff_estimated_delivery  ,time_to_deliver desc;

# B. Find out the top 5 states with the highest & lowest average freight value.
(select c.customer_state as State, round(avg(oi.freight_value),2) as Avg_freight_value,
row_number() over(order by avg(oi.freight_value) desc) as state_rank
from `target_buisness_case.order_items` oi
join `target_buisness_case.orders` o
on oi.order_id=o.order_id
join `target_buisness_case.customers` c
on c.customer_id=o.customer_id
group by c.customer_state
order by avg_freight_value desc
limit 5)
union distinct
(select c.customer_state as State, round(avg(oi.freight_value),2) as Avg_freight_value,
row_number() over(order by avg(oi.freight_value) desc) as state_rank
from `target_buisness_case.order_items` oi
join `target_buisness_case.orders` o
on oi.order_id=o.order_id
join `target_buisness_case.customers` c
on c.customer_id=o.customer_id
group by c.customer_state
order by avg_freight_value
limit 5)
order by state_rank;

# C. Find out the top 5 states with the highest & lowest average delivery time.
(select c.customer_state as State,
ROUND(avg(date_diff(order_delivered_customer_date,order_purchase_timestamp,day)),2) as avg_delivery_time,
row_number() over(order by avg(date_diff(order_delivered_customer_date,order_purchase_timestamp,day)) desc) state_rank
from `target_buisness_case.order_items` oi
join `target_buisness_case.orders` o
on oi.order_id=o.order_id
join `target_buisness_case.customers` c
on c.customer_id=o.customer_id
group by c.customer_state
order by avg_delivery_time desc
limit 5)
union distinct
(select c.customer_state as State,
ROUND(avg(date_diff(order_delivered_customer_date,order_purchase_timestamp,day)),2) as avg_delivery_time,
row_number() over(order by avg(date_diff(order_delivered_customer_date,order_purchase_timestamp,day)) desc) state_rank
from `target_buisness_case.order_items` oi
join `target_buisness_case.orders` o
on oi.order_id=o.order_id
join `target_buisness_case.customers` c
on c.customer_id=o.customer_id
group by c.customer_state
order by avg_delivery_time
limit 5)
order by state_rank;

-------

#D. Find out the top 5 states where the order delivery is really fast as compared to
#the estimated date of 

with cte as
(select c.customer_state fastest_state_for_delivery, 
round(avg(date_diff(order_delivered_customer_date,order_estimated_delivery_date,day)),2) as avg_diff_in_expected_time
from `target_buisness_case.customers` c
join
`target_buisness_case.orders` o
on o.customer_id=c.customer_id
group by c.customer_state
order by avg_diff_in_expected_time
limit 5)
select *,
row_number() over(order by avg_diff_in_expected_time) as state_rank
from cte
order by cte.avg_diff_in_expected_time;

----VI. Analysis based on the payments:
 # A. Find the month on month no. of orders placed using different payment types

SELECT 
  EXTRACT(YEAR FROM O.order_purchase_timestamp)AS order_year,
  EXTRACT(MONTH FROM O.order_purchase_timestamp) AS order_month,
  P.payment_type,
  COUNT(distinct O.order_id) AS num_orders
FROM `target_buisness_case.orders` O
JOIN `target_buisness_case.payments` P
ON O.order_id=P.order_id
 GROUP BY
  order_year, order_month, P.payment_type
ORDER BY
  order_year, order_month,P.payment_type;

#B. Find the no. of orders placed on the basis of the payment installments that have been paid.

select payment_installments,count(order_id) as number_of_orders
from `target_buisness_case.payments`
where payment_value>0
group by payment_installments
having payment_installments>=1
order by payment_installments ;







