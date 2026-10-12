---------TOTAL SALES BY YEAR------
SELECT
YEAR([order_date]) AS YEARS,
SUM([sales_amount]) AS TOTAL_SALES
FROM 
[gold].[fact_sales]
WHERE order_date IS NOT NULL
GROUP BY YEAR([order_date])
ORDER BY YEAR([order_date])

---------TOTAL SALES BY MONTH------
SELECT
MONTH([order_date]) AS MONTHS ,
SUM([sales_amount]) AS TOTAL_SALES
FROM 
[gold].[fact_sales]
WHERE order_date IS NOT NULL
GROUP BY MONTH([order_date])
ORDER BY MONTH([order_date])

-------- TOTAL SALES BY MONTH & RUNNING TOTAL / RUNNING AVERAGE SALES OVER TIME -------
SELECT 
[order_date],
TOTAL_SALES,
SUM(TOTAL_SALES) OVER (ORDER BY [order_date] ) AS RUNNING_SALES,
AVG(AVERAGE_SALES) OVER (ORDER BY [order_date] ) AS RUNNING_AVERAGE
FROM
	(SELECT
	DATETRUNC(MONTH,[order_date]) AS order_date ,
	SUM([sales_amount]) AS TOTAL_SALES,
	AVG([sales_amount]) AS AVERAGE_SALES
	FROM 
	[gold].[fact_sales]
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(MONTH,[order_date])
	) T 
----------PERFORMANCE ANALYSIS--------
---------------YEARLY PERFORMANE OF PRODUCTS COMPARE BY AVERAGE SALES & PREVIOUS YEAR--------
WITH YEARLY_PRODUCT_SALES AS (	
	SELECT 
	YEAR(F.[order_date]) AS ORDER_YEAR,
	P.[product_name],
	SUM(F.[sales_amount]) AS CURRENT_SALES
	FROM 
	[gold].[fact_sales] F
	LEFT JOIN [gold].[dim_products] P
	ON F.[product_key] = P.product_key
	WHERE F.[order_date] IS NOT NULL
	GROUP BY YEAR(F.[order_date]) ,
	P.[product_name]
	)

SELECT 
ORDER_YEAR,
product_name AS PRODUCT_NAME,
CURRENT_SALES,
AVG(CURRENT_SALES) OVER(PARTITION BY product_name ) AS AVG_SALES, 
CURRENT_SALES - AVG(CURRENT_SALES) OVER(PARTITION BY product_name ) AS DIFF_AVG,
----ADDING FLAG---
CASE WHEN CURRENT_SALES - AVG(CURRENT_SALES) OVER(PARTITION BY product_name ) > 0 THEN 'ABOVE_AVG'
	 WHEN CURRENT_SALES - AVG(CURRENT_SALES) OVER(PARTITION BY product_name ) < 0 THEN 'BELOW_AVG'
	 ELSE 'AVG'
END AVG_CHANGE,
------- YOY ANALYSIS-----
LAG (CURRENT_SALES)  OVER(PARTITION BY product_name ORDER BY  ORDER_YEAR ) AS PRE_YEAR,
CURRENT_SALES - LAG (CURRENT_SALES)  OVER(PARTITION BY product_name ORDER BY  ORDER_YEAR ) AS DIFF_PREV, 
---- ADDING FLAG ---
CASE WHEN CURRENT_SALES - LAG (CURRENT_SALES)  OVER(PARTITION BY product_name ORDER BY  ORDER_YEAR ) > 0 THEN 'INCRAESING'
	 WHEN CURRENT_SALES - LAG (CURRENT_SALES)  OVER(PARTITION BY product_name ORDER BY  ORDER_YEAR ) < 0 THEN 'DECREASING'
	 ELSE 'NO CHANGE'
END PREV_YEAR_CHANGE
FROM YEARLY_PRODUCT_SALES
ORDER BY PRODUCT_NAME, ORDER_YEAR

------------------- PART TO WHOLE ANLYSIS-------
---- WHICH CATEGORIES COTRIBUTE MORE IN OVERSALES-----
WITH CTAEGORY_SALES AS 	
	(SELECT 
	P.category,
	SUM(F.sales_amount) AS TOTAL_SALES
	FROM 
	[gold].[fact_sales] F
	LEFT JOIN [gold].[dim_products] P
	ON F.[product_key] = P.product_key
	GROUP BY category)
SELECT
category,
TOTAL_SALES AS TOTAL_FOR_CATEGORY, 
SUM(TOTAL_SALES) OVER () AS TOTAL_ALL,
CONCAT(ROUND(CAST(TOTAL_SALES AS FLOAT) /SUM(TOTAL_SALES) OVER () * 100 , 2),'%') AS PERCENTAGE_AMMOUNT
FROM
CTAEGORY_SALES
ORDER BY PERCENTAGE_AMMOUNT  DESC



---------------- DATA SEGMENTATION --------
---- SEGMENT PRODUCTS COST RANGES --------------
WITH PROUDCT_SEGMENTATION AS 
	(SELECT
	[product_key],
	[product_name],
	[cost],
	CASE WHEN cost < 100 THEN 'BELOW 100'
		WHEN COST BETWEEN 100 AND 500 THEN '100-500'
		WHEN COST BETWEEN 500 AND 1000 THEN '500-1000'
		ELSE 'ABOVE 1000'
	END COST_RANGE
	FROM 
	[gold].[dim_products])
SELECT 
COST_RANGE,
COUNT(COST_RANGE) AS TOTAL_PRODUCTS 
FROM PROUDCT_SEGMENTATION
GROUP BY COST_RANGE
ORDER BY TOTAL_PRODUCTS  DESC

------ CUSTOMER SEGMENTATION SPENDING BEHAVIOUR-----
WITH CUSTOMER_LIFE_SPAN AS	
	(SELECT 
	C.[customer_key],
	SUM(F.[sales_amount]) AS TOTAL_SPENDING,
	MIN([order_date]) AS FIRST_ORDER,
	MAX([order_date]) AS LAST_ORDER,
	DATEDIFF(MONTH,MIN([order_date]),MAX([order_date])) AS LIFE_SPAN
	FROM [gold].[fact_sales] F
	LEFT JOIN [gold].[dim_customers] C
	ON F.[customer_key]= C.[customer_key]
	GROUP BY C.[customer_key]
	)

,CUSTOMER_SEGMENTATION AS
	(SELECT
	customer_key,
	TOTAL_SPENDING,
	LIFE_SPAN,
	CASE WHEN LIFE_SPAN >=12 AND  TOTAL_SPENDING > 5000 THEN 'VIP'
		WHEN LIFE_SPAN >=12 AND  TOTAL_SPENDING <= 5000 THEN 'REGULAR'
		ELSE 'NEW'
	END AS CUSTOMER_SEGMENT
	FROM 
	CUSTOMER_LIFE_SPAN
	)

SELECT 
CUSTOMER_SEGMENT,
COUNT(CUSTOMER_SEGMENT) AS TOTAL_SEGMENTATION
FROM
CUSTOMER_SEGMENTATION
GROUP BY CUSTOMER_SEGMENT
ORDER BY CUSTOMER_SEGMENT 


/*
===============================================================================
Customer Report
===============================================================================
Purpose:
    - This report consolidates key customer metrics and behaviors

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
    2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
        - total orders
        - total sales
        - total quantity purchased
        - total products
        - lifespan (in months)
    4. Calculates valuable KPIs:
        - recency (months since last order)
        - average order value
        - average monthly spend
===============================================================================
*/
CREATE VIEW gold_report_customers AS
------ FIRST WRITTING BASE QUERY------
WITH BASE_QUERY AS 
	(SELECT 
	F.[order_number],
	F.[quantity],
	F.[product_key],
	F.[sales_amount],
	F.[order_date],
	C.[customer_key],
	C.[customer_number],

	CONCAT(C.[first_name],' ',C.[last_name]) AS CUSTOMER_NAME,
	DATEDIFF(YEAR,C.[birthdate],GETDATE()) AS AGE 
	FROM [gold].[fact_sales] F 
	LEFT JOIN [gold].[dim_customers] C
	ON C.[customer_key] = F.[customer_key]
	WHERE order_date IS NOT NULL )
,
------------ AGGREGATIONS FOR CUSTOMERS--------------
CUSTOMER_AGGREGATONS AS
(
	SELECT
	[customer_key],
	[customer_number],
	CUSTOMER_NAME ,
	AGE,
	COUNT(DISTINCT order_number) AS TOTAL_ORDERS,
	MAX (ORDER_DATE) AS LAST_ORDER ,
	COUNT(DISTINCT PRODUCT_KEY) AS TOTAL_PRODUCTS,
	SUM(QUANTITY) AS TOTAL_QUANTITY,
	SUM(SALES_AMOUNT) AS TOTAL_SALES ,
	DATEDIFF(MONTH,MIN (ORDER_DATE),MAX (ORDER_DATE)) AS LIFE_SPAN
	FROM BASE_QUERY
	GROUP BY [customer_key],
	[customer_number],
	CUSTOMER_NAME ,
	AGE)
------- SEGMENTATION----
SELECT
[customer_key],
[customer_number],
CUSTOMER_NAME ,
AGE,
CASE WHEN AGE < 20 THEN 'UNDER 20'
	WHEN AGE BETWEEN 20 AND 29 THEN '20-29'
	WHEN AGE BETWEEN 30 AND 39 THEN '30- 39'
	WHEN AGE BETWEEN 40 AND 49 THEN '40 -49'
ELSE 'ABOVE 50'
END AS AGE_CALSSIFICATION ,
CASE WHEN LIFE_SPAN >=12 AND  TOTAL_SALES > 5000 THEN 'VIP'
	WHEN LIFE_SPAN >=12 AND  TOTAL_SALES <= 5000 THEN 'REGULAR'
	ELSE 'NEW'
END AS CUSTOMER_SEGMENT ,
TOTAL_ORDERS,
DATEDIFF(MONTH,LAST_ORDER, GETDATE()) AS RECENCY,
LAST_ORDER ,
TOTAL_PRODUCTS,
TOTAL_QUANTITY,
TOTAL_SALES,
LIFE_SPAN, 
CASE WHEN TOTAL_SALES = 0 THEN 0
ELSE TOTAL_SALES/ TOTAL_ORDERS 
END AS AVG_ORDER_VALUE,
--- average monthly spent---
CASE WHEN LIFE_SPAN =0 THEN TOTAL_SALES
	ELSE TOTAL_SALES / LIFE_SPAN 
END AS AVERAGE_MONTHLY_SPEND
FROM
CUSTOMER_AGGREGATONS

/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
        - total orders OK
        - total sales OK
        - total quantity sold OK
        - total customers (unique) OK 
        - lifespan (in months)
    4. Calculates valuable KPIs:
        - recency (months since last sale)
        - average order revenue (AOR)
        - average monthly revenue
===============================================================================
*/
---- FIRST BASE QUERY ----
CREATE VIEW PRODUCTS_REPORT AS 
WITH BASIC_QUERY AS
	(SELECT 
	F.[customer_key],
	P.[product_name],
	P.[category],
	P.[subcategory],
	P.[cost],
	F.[product_key],
	F.[sales_amount],
	F.[order_number],
	F.[order_date],
	F.[quantity]
	FROM [gold].[fact_sales] F
	LEFT JOIN [gold].[dim_products] P
	ON F.[product_key] = P.[product_key]
	WHERE order_date IS NOT NULL)
 ,
 ----AGGREAION FOR PRODUCTS----
	PRODUCTS_AGG AS
	(SELECT
		[product_key],
		[product_name],
		[category],
		[subcategory],
		MAX(ORDER_DATE)	AS LAST_ORDER,
		SUM([sales_amount]) AS TOTAL_SALES,
		COUNT (DISTINCT order_number) AS TOTAL_ORDERS,
		COUNT (DISTINCT [customer_key]) AS TOTAL_CUSTOMERS,
		SUM ([quantity]) AS TOTAL_QUANTITY,
		DATEDIFF(MONTH,MIN (ORDER_DATE),MAX (ORDER_DATE)) AS LIFE_SPAN
	 FROM 
	 BASIC_QUERY
	 GROUP BY 
		[product_key],
		[product_name],
		[category],
		[subcategory] )


SELECT
product_key,
[product_name],
[category],
[subcategory],
LAST_ORDER,
TOTAL_SALES,
TOTAL_ORDERS,
TOTAL_CUSTOMERS,
TOTAL_QUANTITY,
 LIFE_SPAN,
 CASE WHEN  TOTAL_SALES > 50000 THEN 'High-Performer'
	WHEN TOTAL_SALES > 10000 THEN 'Mid-Range'
	ELSE 'Low-Performer'
	END AS PRODUCT_SEGMENT,
 DATEDIFF( MONTH,LAST_ORDER,GETDATE())AS RECENCY,
 CASE WHEN TOTAL_SALES = 0 THEN 0
    ELSE TOTAL_SALES / TOTAL_ORDERS
	END AS AVERAGE_ORDER_REVENUE ,
CASE WHEN LIFE_SPAN = 0 THEN TOTAL_SALES
    ELSE TOTAL_SALES /LIFE_SPAN
	END AS AVERAGE_MONTHLY_REVENUE 
FROM PRODUCTS_AGG 
