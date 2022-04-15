# Questions from marketing team

## 1. Which film title was the most recommended for all customers?

### Steps:
- Use 
- 
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



## 2. How many customers were included in the email campaign?

### Steps:
- Use 


````sql
SELECT
    COUNT(DISTINCT customer_id)
FROM report_table;
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

## 3. Out of all the possible films - what percentage coverage do we have in our recommendations?

### Steps:
- Use

````sql

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
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |



## 4. What is the most popular top category?

### Steps:
- Use

````sql
Select
    category_name,
    COUNT(*) as count_cate
FROM first_top_category_insights
GROUP BY category_name
ORDER BY count_cate DESC;
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |




## 5. What is the 4th most popular top category?

### Steps:
- Use

````sql
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
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |



## 6. What is the average percentile ranking for each customer in their top category
### Steps:
- Use

````sql
Select
    round(avg(percentile)::NUMERIC,3)
From first_top_category_insights;
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |


## 7. What is the cumulative distribution of the top 5 percentile values for the top category from the first_category_insights table
### Steps:
- Use

````sql
SELECT
  ROUND(percentile) as percentile,
  COUNT(*),
  ROUND(100*CUME_DIST() OVER(ORDER BY ROUND(percentile))) AS cum_dist
FROM first_top_category_insights
GROUP BY 1
ORDER BY 1;
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |



## 8. What is the median of the second category percentage of entire viewing history?
### Steps:
- Use

````sql

Select 
  percentile_cont(0.5) within Group(order by percentage_difference) as median
from second_category_insights;
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |



## 9. What is the 80th percentile of films watched featuring each customer’s favourite actor?
### Steps:
- Use

````sql
SELECT 
 PERCENTILE_CONT(0.8) within Group(order by rental_count) as 8th_percentile
FROM top_actor_counts;
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

    
    
 ## 10. What was the average number of films watched by each customer
### Steps:
- Use

````sql
SELECT
    round(AVG(total_count))
From total_counts;
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |


 ## 11. What is the top combination of top 2 categories and how many customers if the order is relevant
### Steps:
- Use

````sql
Select  
    cat_1,
    cat_2,
    COUNT(customer_id) as number_of_customer
FROM report_table
GROUP BY cat_1,
         cat_2
ORDER BY number_of_customer DESC
LIMIT 1;
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |


 ## 12. Which actor was the most popular for all customers?
### Steps:
- Use

````sql
SELECT 
    actor_name,
    COUNT(*) as occurence
FROM report_table
GROUP BY actor_name 
ORDER BY occurence DESC 
LIMIT 1;
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |



 ## 13. How many films on average had customers already seen that feature their favourite actor
### Steps:
- Use

````sql
Select
    ROUND(AVG(rental_count))
FROM top_actor_counts;
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

