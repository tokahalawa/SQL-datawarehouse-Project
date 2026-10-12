SELECT *FROM INFORMATION_SCHEMA.COLUMNS ;
SELECT DISTINCT category FROM [gold].[dim_products]
-----------
---- TO GET DATE DIFFRENCE AND RANGE-----
SELECT MIN(order_date),
MAX(order_date),
DATEDIFF(YEAR,MIN(order_date),MAX(order_date)) AS order_range_years
FROM [gold].[fact_sales] 
--------------
------- TO GET BIRTHDATES------
SELECT 
MIN(birthdate) AS oldest_birthdate,
DATEDIFF(YEAR ,MIN(birthdate) ,GETDATE()) AS OLDEST_AGE,
max(birthdate) AS youngest_birthdate,
DATEDIFF(YEAR,MIN(birthdate),max(birthdate)) AS age_diffence
FROM 
[gold].[dim_customers]

--------------------------------------
-----GETTING BG NUMBERS (MEAUSERS)----
SELECT 'TOTAL SALES' AS meausrre_name,SUM(sales_amount) AS measure_value FROM [gold].[fact_sales] 
UNION ALL
SELECT 'TOTAL_QUANTITY',SUM([quantity]) FROM [gold].[fact_sales] 
UNION ALL
SELECT 'AVG_SALES',AVG(sales_amount) FROM [gold].[fact_sales] 
UNION ALL
SELECT 'TOTAL_ORDERS',COUNT(DISTINCT[order_number]) FROM [gold].[fact_sales] 
UNION ALL
SELECT 'TOTAL_produdcts',COUNT(DISTINCT(product_key)) FROM [gold].[dim_products]
UNION ALL
SELECT 'TOTAL_CUSTOMERS',COUNT(DISTINCT(customer_key)) FROM [gold].[dim_customers]
--------------- GETTING MAGNITUDES OF DATA ----------
--TOTAL CUSTOMERS FOR EACH COUNTRY-----
SELECT
[country],
COUNT(customer_key) AS TOTAL_CUSTOMERS 
FROM [gold].[dim_customers]
GROUP BY [country]
ORDER BY TOTAL_CUSTOMERS DESC
--TOTAL CUSTOMERS FOR EACH GENDER-----
SELECT
[gender],
COUNT(customer_key) AS TOTAL_CUSTOMERS 
FROM [gold].[dim_customers]
GROUP BY [gender]
ORDER BY TOTAL_CUSTOMERS DESC
--TOTAL PRODUCTS FOR EACH CATEGORY -----

SELECT 
[category],
COUNT(DISTINCT(product_key)) AS TOTAL_PRODUCTS
FROM [gold].[dim_products]
GROUP BY [category]
ORDER BY TOTAL_PRODUCTS DESC

--AVERAGE COST FOR EACH CATEGORY -----

SELECT 
[category],
AVG(cost) AS AVERAGE_COST
FROM [gold].[dim_products]
GROUP BY [category]
ORDER BY AVERAGE_COST DESC
--REVENUE FOR EACH CATEGORY -----
SELECT 
[category],
AVG(cost) AS AVERAGE_COST
FROM [gold].[dim_products]
GROUP BY [category]
ORDER BY AVERAGE_COST DESC


------- REVENUE FOR EACH CATEGORY------
SELECT 
P.category,
SUM(F.[sales_amount])  AS REVENUE
FROM [gold].[fact_sales] F 
 LEFT JOIN [gold].[dim_products] P
ON P.[product_key]=F.[product_key]
GROUP BY P.category
ORDER BY REVENUE DESC

------- REVENUE FOR EACH CUSTOMER------
SELECT 
C.[customer_key],
C.[first_name],
C.[last_name],
SUM(F.[sales_amount])  AS REVENUE
FROM [gold].[fact_sales] F 
 LEFT JOIN [gold].[dim_customers] C
ON C.[customer_key]=F.[customer_key]
GROUP BY C.[customer_key],
C.[first_name],
C.[last_name]
ORDER BY REVENUE DESC

------- SOLD ITEMS ACROSS COUNTRIES---
SELECT 
C.country,
SUM(F.[quantity])  AS TOTAL_SOLD_ITEMS
FROM [gold].[fact_sales] F 
 LEFT JOIN [gold].[dim_customers] C
ON C.[customer_key]=F.[customer_key]
GROUP BY C.country 
ORDER BY  TOTAL_SOLD_ITEMS DESC

-------------5 PRODUCTS HIGHEST REVENUE------
SELECT TOP 5
P.[product_name],
SUM(F.[sales_amount])  AS REVENUE
FROM [gold].[fact_sales] F 
 LEFT JOIN [gold].[dim_products] P
ON P.[product_key]=F.[product_key]
GROUP BY P.[product_name]
ORDER BY REVENUE DESC
-------------5 PRODUCTS WOST REVENUE------
SELECT TOP 5
P.[product_name],
SUM(F.[sales_amount])  AS REVENUE
FROM [gold].[fact_sales] F 
 LEFT JOIN [gold].[dim_products] P
ON P.[product_key]=F.[product_key]
GROUP BY P.[product_name]
ORDER BY REVENUE 



---- OR USING WINDOW FUNCTION -----
SELECT * FROM 
(
	SELECT 
	P.[product_name],
	SUM(F.[sales_amount])  AS TOTAL_REVENUE ,
	ROW_NUMBER() OVER (ORDER BY SUM(F.[sales_amount]) DESC) AS RANK_RPODUCTS 
	FROM [gold].[fact_sales] F 
	 LEFT JOIN [gold].[dim_products] P
	ON P.[product_key]=F.[product_key]
	GROUP BY P.[product_name] ) T
WHERE RANK_RPODUCTS <= 5 

-----------------  Find the Top-10 customers who have generated the highest revenue
----------------And 3 customers with the fewest orders placed
SELECT * FROM 
(
	SELECT 
	C.[customer_key],
	C.[first_name],
	C.[last_name],
	CONCAT(C.[first_name],C.[last_name]) AS FULL_NAME,
	ROW_NUMBER() OVER (ORDER BY SUM(F.[sales_amount]) DESC) AS RANK_CUSTOMER 
	FROM [gold].[fact_sales] F 
	 LEFT JOIN [gold].[dim_customers] C
	ON C.[customer_key]=F.[customer_key]
	GROUP BY C.[customer_key],
	C.[first_name],
	C.[last_name],
	CONCAT(C.[first_name],C.[last_name]))  T
WHERE RANK_CUSTOMER <=10 

----------------And 3 customers with the fewest orders placed
SELECT * FROM 
(
	SELECT 
	C.[customer_key],
	C.[first_name],
	C.[last_name],
	CONCAT(C.[first_name],' ',C.[last_name]) AS FULL_NAME,
	ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT[order_number] ) ASC) AS RANK_CUSTOMER 
	FROM [gold].[fact_sales] F 
	 LEFT JOIN [gold].[dim_customers] C
	ON C.[customer_key]=F.[customer_key]
	GROUP BY C.[customer_key],
	C.[first_name],
	C.[last_name],
	CONCAT(C.[first_name],' ', C.[last_name]))  T
WHERE RANK_CUSTOMER <=3 



SUM(F.price)-SUM(P.cost) AS REVENUE