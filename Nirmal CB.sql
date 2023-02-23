USE gdb023;
SHOW TABLES;
SHOW COLUMNS FROM dim_customer;

#1 selecting the market of Atliq Exclusive wrt regioin

select distinct market from dim_customer
where customer = "Atliq Exclusive" and region = "APAC";

#2 percentage of unique products increasing

SHOW COLUMNS FROM dim_product;
drop table if exists prod_per_year;

CREATE TABLE prod_per_year select distinct fact_manufacturing_cost.product_code,segment,product,cost_year,manufacturing_cost from dim_product
right join fact_manufacturing_cost 
on dim_product.product_code = fact_manufacturing_cost.product_code;

select count(distinct case when cost_year = 2020 then product_code end) as unique_products_2020,
count(distinct case when cost_year = 2021 then product_code end) as unique_products_2021,
round(
(count(distinct case when cost_year = 2021 then product_code end) - 
count(distinct case when cost_year = 2020 then product_code end)) / count(distinct case when cost_year = 2020 then product_code end)
*100, 2) as percentage_chg from prod_per_year; 

#3 count of unique products by segment

select segment, count(distinct product_code) as product_count from prod_per_year
group by segment
order by count(distinct product_code) DESC;

#4 product increasing by year

select segment, count(distinct case when cost_year = 2020 then product_code end) as product_count_2020,
count(distinct case when cost_year = 2021 then product_code end) as product_count_2021,
count(distinct case when cost_year = 2021 then product_code end) - count(distinct case when cost_year = 2020 then product_code end) as difference 
from prod_per_year
group by segment
order by difference DESC;

#5 product by highest & lowest manufacturing cost

select fact_manufacturing_cost.product_code,product, 
max(manufacturing_cost) as mfg_cost from dim_product
left outer join fact_manufacturing_cost on
dim_product.product_code = fact_manufacturing_cost.product_code
group by dim_product.product_code, dim_product.product
order by mfg_cost DESC
limit 1;

select fact_manufacturing_cost.product_code,product, 
min(coalesce(fact_manufacturing_cost.manufacturing_cost,9999999)) as mfg_cost1 from dim_product
left outer join fact_manufacturing_cost on
dim_product.product_code = fact_manufacturing_cost.product_code
group by dim_product.product_code, dim_product.product
ORDER BY mfg_cost1 ASC
Limit 1;

#6 Top 5 customers with average high pre_invoice_discount_pct for 2021

show columns from fact_pre_invoice_deductions;

select fact_pre_invoice_deductions.customer_code,customer,round(avg(pre_invoice_discount_pct)*100) as average_discount_percentage from dim_customer 
right outer join fact_pre_invoice_deductions on
dim_customer.customer_code = fact_pre_invoice_deductions.customer_code
where fiscal_year = 2021 and market = 'India'
group by fact_pre_invoice_deductions.customer_code,customer
order by average_discount_percentage DESC
LIMIT 5;

show tables;

#7 Gross sales of Atliq Exclusive for each month

ALTER TABLE fact_sales_monthly RENAME COLUMN date to sales_date;
ALTER TABLE dim_customer RENAME COLUMN channel to cus_channel;

Drop table if exists sales_table;

create table sales_table(select sold_quantity,customer,product,gross_price,sales_date,cus_channel, fact_sales_monthly.fiscal_year,
(sold_quantity * gross_price) as gross_sales from fact_sales_monthly 
inner join dim_customer on 
fact_sales_monthly.customer_code = dim_customer.customer_code 
inner join dim_product on 
fact_sales_monthly.product_code = dim_product.product_code
inner join fact_gross_price on
fact_gross_price.product_code = fact_sales_monthly.product_code);

select year(sales_date),month(sales_date), round(sum(gross_sales)/1000000) as sales_in_mln from sales_table
where customer = "Atliq Exclusive"
group by year(sales_date),month(sales_date)
order by year(sales_date);



#8 total sold quantity by quater for the year 2020

select quarter(sales_date) as No_of_quarter, sum(sold_quantity) as total_quantity from sales_table
where year(sales_date) = 2020
group by quarter(sales_date)
order by total_quantity DESC;

show columns from sales_table;

#9 %of channel contribution in total sales
SELECT cus_channel, sum(gross_sales)/1000000 as gross_in_mln,
((sum(gross_sales)/1000000)/(select sum(gross_sales)/1000000 from sales_table
where fiscal_year = 2021)* 100) as percentage 
from sales_table
where fiscal_year = 2021
group by cus_channel
order by percentage DESC;

#10 Top 3 products in each division by sales in the year 2021

Select product, fact_sales_monthly.product_code,division,sum(sold_quantity) as total_sold_quantity,
rank() over(sold_quantity) as rank_ 
from fact_sales_monthly 
right join dim_product on
fact_sales_monthly.product_code = dim_product.product_code
where fiscal_year = 2021
group by division,product_code,product;


SELECT division, fact_sales_monthly.product_code,product,
SUM(sold_quantity) AS total_sold_quantity,
  @rank := IF(@prev_division = division, @rank + 1, 1) AS rank_order,
  @prev_division := division as division_group
from fact_sales_monthly
right join dim_product on
fact_sales_monthly.product_code = dim_product.product_code
WHERE fiscal_year = 2021
GROUP BY division,product_code,product
HAVING rank_order <= 3
ORDER BY division, rank_order;

