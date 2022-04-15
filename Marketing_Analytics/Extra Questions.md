# Questions from marketing team


## 1. Which film title was the most recommended for all customers?

### Steps:
- Use **INNER JOIN** to merge ```rental```, ```inventory``` ,```film```,```film_category```and```category```.
- **INNER JOIN** and **LEFT JOIN** are them same. I did some tests to see whether there is a difference, which shows below.


````sql
with cte as
(Select 
    title
From category_recommendations
UNION ALL
Select 
    title
From actor_recommendations
)
  Select
      title,
      COUNT( title) as reco_count
  FROM cte
  GROUP BY title
ORDER BY reco_count DESC;
);
````
   
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |


</details>




/* -------------------------------------------------
How many customers were included in the email campaign?
---------------------------------------------------- */

SELECT
    COUNT(DISTINCT customer_id)
FROM report_table;

/* -------------------------------------------------
Out of all the possible films - what percentage coverage do we have in 
our recommendations? (total unique films recommended divided by total available films)
---------------------------------------------------- */

with cte as
(Select 
    title
From category_recommendations
UNION 
Select 
    title
From actor_recommendations
)
  Select  
      Count(distinct A.title) as film_reco,
      Count(distinct B.title) as film_total,
      ROUND( Count(distinct A.title)::NUMERIC/Count(distinct B.title)::NUMERIC,5) as coverager
  From cte A 
  CROSS JOIN dvd_rentals.film B;

/* -------------------------------------------------
What is the most popular top category?
---------------------------------------------------- */

Select
    category_name,
    COUNT(*) as count_cate
FROM first_top_category_insights
GROUP BY category_name
ORDER BY count_cate DESC;

/* -------------------------------------------------
What is the 4th most popular top category?
---------------------------------------------------- */

WITH cte AS
(
Select
    category_name,
     COUNT(*),
    ROW_NUMBER() OVER(ORDER BY COUNT(*) DESC) as ranked
FROM first_top_category_insights
GROUP BY 1
)
  Select 
      category_name
  From cte
  where ranked = 4;

/* -------------------------------------------------
What is the average percentile ranking for each customer in their top category rounded to the nearest
2 decimal places? Hint: be careful of your data types!
---------------------------------------------------- */

Select
    round(avg(percentile)::NUMERIC,3)
From first_top_category_insights


/* -------------------------------------------------
What is the cumulative distribution of the top 5 percentile values for the top category 
from the first_category_insights table rounded to the nearest round percentage?
- 5% below 5th percentile
---------------------------------------------------- */

SELECT
  ROUND(percentile) as percentile,
  COUNT(*),
  ROUND(100*CUME_DIST() OVER(ORDER BY ROUND(percentile))) AS cum_dist
FROM first_top_category_insights
GROUP BY 1
ORDER BY 1;


/* -------------------------------------------------
What is the median of the second category percentage of entire viewing history?
---------------------------------------------------- */

Select 
  percentile_cont(0.5) within Group(order by percentage_difference) as median
from second_category_insights

/* -------------------------------------------------
What is the 80th percentile of films watched featuring each customer’s favourite actor?
---------------------------------------------------- */

SELECT 
 PERCENTILE_CONT(0.8) within Group(order by rental_count) as 8th_percentile
FROM top_actor_counts

    
/* -------------------------------------------------
What was the average number of films watched by each customer
rounded to the nearest whole number?
---------------------------------------------------- */

SELECT
    round(AVG(total_count))
From total_counts

/* -------------------------------------------------
What is the top combination of top 2 categories and how many customers 
if the order is relevant (e.g. Horror and Drama is a different combination to Drama and Horror)
-> meaning: Find two category which have highest number of customer
---------------------------------------------------- */

Select  
    cat_1,
    cat_2,
    COUNT(customer_id) as number_of_customer
FROM report_table
GROUP BY cat_1,
         cat_2
ORDER BY number_of_customer DESC 
limit 5

/* -------------------------------------------------
Which actor was the most popular for all customers?
---------------------------------------------------- */
SELECT 
    actor_name,
    COUNT(*) as occurence
FROM report_table
GROUP BY actor_name 
ORDER BY occurence DESC 
LIMIT 4

/* -------------------------------------------------
How many films on average had customers already seen that feature their favourite actor rounded to closest integer?
---------------------------------------------------- */

Select
    ROUND(AVG(rental_count))
FROM top_actor_counts
