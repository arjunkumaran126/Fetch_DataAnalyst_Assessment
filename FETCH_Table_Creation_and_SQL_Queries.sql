create table Users (
id VARCHAR(255) primary key,
created_date TIMESTAMP NOT NULL, -- not null constraint is used as created_date cannot be null
birth_date TIMESTAMP,
state VARCHAR(255),
language VARCHAR(255),
gender VARCHAR(255)
);


create table Products (
category_1 VARCHAR(255),
category_2 VARCHAR(255),
category_3 VARCHAR(255),
category_4 VARCHAR(255),
manufacturer VARCHAR(255),
brand VARCHAR(255),
barcode BIGINT primary key -- BIGINT was used because value was out of range for Integer
);

create table Transactions (
receipt_id VARCHAR(255),
purchase_date TIMESTAMP,
scan_date TIMESTAMP,
store_name VARCHAR(255),
user_id VARCHAR(255),
barcode BIGINT,
final_quantity numeric(10,2),
final_sale numeric(10,2)
);




-- What are the top 5 brands by receipts scanned among users 21 and over?

WITH age_filtered_users_cte AS    -- cte to get product and transaction data for users 21 and over 
(
SELECT 	t.barcode, 
		t.final_quantity,
		p.brand   
FROM 
		transactions t
JOIN 					 -- using inner join to get all matching records from transactions and products
		products p 
ON 	t.barcode = p.barcode
JOIN 					 -- using inner join to get all matching records from transactions and users
		users u 
ON 	t.user_id = u.id  
WHERE 
		CURRENT_DATE - u.birth_date >=  '21 years'::interval  -- Filter to check if user is 21 and over
AND 	p.brand <> ''	
AND 	u.birth_date IS NOT NULL
)
SELECT 	brand,
    	SUM(final_quantity) AS total_quantity,  
   	 	RANK() OVER (ORDER BY SUM(final_quantity) DESC) AS brand_rank
FROM 
		age_filtered_users_cte
GROUP BY 
		brand
limit 5;				 -- to print top 5

-- What are the top 5 brands by sales among users that have had their account for at least six months?

with account_filtered_users_cte AS -- cte to get product and transaction data for users who had accs for more than 6 months 
(
SELECT 	p.brand, 
		t.final_sale
FROM 
		transactions t		
JOIN 					
		products p 			-- using inner join to get all matching rows from transactions and products
ON t.barcode = p.barcode
JOIN 
		users u 
ON t.user_id = u.id			-- using inner join to get all matching rows from transactions and users
WHERE 
		CURRENT_DATE - u.created_date >= '6 months'::interval  -- Filter to check if user had their account for atleast 6 months
AND 	p.brand <> ''		-- Brand should not be null
)
SELECT 	brand,
		SUM(final_sale) as total_sale,	
		RANK() over (order by SUM(final_sale) desc) as brand_rank
FROM 	
		account_filtered_users_cte
GROUP BY 
		brand
LIMIT 5;					-- to print top 5


--  What is the percentage of sales in the Health & Wellness category by generation?

WITH data_with_generation_cte AS 
(
SELECT CASE  -- categorizing users based on their birth date to determine their generation
        	WHEN CURRENT_DATE - u.birth_date < '28 years'::interval THEN 'Gen Z'
            WHEN CURRENT_DATE - u.birth_date >= '28 years'::interval AND CURRENT_DATE - u.birth_date < '43 years'::interval THEN 'Millennials'
            WHEN CURRENT_DATE - u.birth_date >= '43 years'::interval AND CURRENT_DATE - u.birth_date < '59 years'::interval THEN 'Gen X'
            WHEN CURRENT_DATE - u.birth_date >= '59 years'::interval AND CURRENT_DATE - u.birth_date < '78 years'::interval THEN 'Baby Boomers'
            WHEN CURRENT_DATE - u.birth_date >= '78 years'::interval AND CURRENT_DATE - u.birth_date < '96 years'::interval THEN 'Silent Generation'
            ELSE NULL  -- Exclude invalid generations
        END AS generation,
        SUM(t.final_sale) AS health_wellness_sales -- Sum of Sales for the health and wellness category for each Generation 
FROM 
	users u
JOIN 
    transactions t ON u.id = t.user_id
JOIN 
    products p ON t.barcode = p.barcode  
WHERE 
    p.category_1 = 'health & wellness' -- filter for health and wellness category
  	AND u.birth_date IS NOT NULL  -- Filter out users with null birth_date
GROUP BY 
    generation
),
total_health_wellness_sales_cte AS 
(
SELECT SUM(t.final_sale) AS total_health_wellness_sales -- total Sum of Sales for the health and wellness category 
FROM 
	transactions t
JOIN 
    products p ON t.barcode = p.barcode  -- using inner join to get all matching rows from transactions and products
JOIN
    users u on t.user_id = u.id			-- using inner join to get all matching rows from transactions and users
WHERE 
    p.category_1 = 'health & wellness'
)
SELECT dg.generation,
       dg.health_wellness_sales, -- Calculating the percentage of sales 
       ROUND((dg.health_wellness_sales::numeric / NULLIF(ts.total_health_wellness_sales, 0)) * 100, 2) AS percentage_sales
FROM
    data_with_generation_cte dg,
    total_health_wellness_sales_cte ts
WHERE 
    dg.generation IS NOT NULL -- not printing null results
ORDER BY 
    dg.generation;
 
   
-- Who are Fetch's power users?

WITH user_metrics_cte AS 	 -- cte to calculate metrics to find power users
(	
SELECT 	u.id,
		COUNT(t.receipt_id) AS total_products,  -- Counting each instance of receipt ID as a product purchase.
		SUM(t.final_sale) AS total_spend		-- Summing sale as total Spend
FROM 
	users u
JOIN 
	transactions t 
ON u.id = t.user_id			-- inner join is used to get matching records from users and transactions
GROUP BY 
	u.id					-- The data is grouped by user id
),
power_users_cte as 				
(
SELECT 	id,
		total_products,
		total_spend,
		RANK() OVER (ORDER BY total_products DESC, total_spend DESC) AS user_rank  -- Ranked using total products and spend
FROM 
	user_metrics_cte
)
SELECT 	id,	
		total_products,
		total_spend,
		user_rank
FROM power_users_cte
ORDER BY user_rank				-- Ordered by user rank
LIMIT 5;


-- Which is the leading brand in the Dips & Salsa category?

SELECT 
    p.brand,
    SUM(t.final_sale) AS total_sales
FROM 
    products p
JOIN 
    transactions t ON p.barcode = t.barcode	-- Using Inner Join to get matching rows from both tables	
WHERE 
	p.category_1 = 'snacks'					-- Category 1 is the main category
AND p.category_2 = 'dips & salsa'			-- Category 2 is the sub catgeory of 1
GROUP BY 
    p.brand									
ORDER BY 		
    total_sales DESC
LIMIT 1;   
   


-- At what percent has Fetch grown year over year?

WITH accounts_per_year_cte AS 
(
SELECT 
	EXTRACT(YEAR FROM u.created_date) AS year,    
    COUNT(u.id) AS accounts_created					 -- Counting id instances as account_created
FROM 	
	users u
GROUP by											 -- grouping the accounts created by year 
    year
)
SELECT 
    year,
    accounts_created,
    LAG(accounts_created) OVER (ORDER BY year) AS previous_year_accounts,-- Using LAG to get # of accounts created in the previous year.
    CASE 											 --	to calculate percentage_growth
        WHEN LAG(accounts_created) OVER (ORDER BY year) IS NOT NULL THEN 
            ROUND((accounts_created - LAG(accounts_created) OVER (ORDER BY year)) * 100.0 /  
            LAG(nullif(accounts_created, 0)) OVER (ORDER BY year), 2)
        ELSE 
            NULL
    END AS accounts_growth_percentage
FROM 
    accounts_per_year_cte
ORDER BY 
    year;
   
   

   
   
   
