# Questions from marketing team

## 1. Which film title was the most recommended for all customers?

### Steps:
- Use 
- 
````sql
With cte as
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
ORDER BY reco_count DESC
LIMIT 1;
````
| title          | reco_count  |
| ---------------| ----------- |
|JUGGLER HARDLY  | 145         |



## 2. How many customers were included in the email campaign?

### Steps:
- Use 


````sql
SELECT
    COUNT(DISTINCT customer_id) as count_customers
FROM report_table;
````
| count_customers |
| ----------------| 
| 599             |


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
      ROUND( Count(distinct A.title)::NUMERIC/Count(distinct B.title)::NUMERIC,5) as coverage
  From cte A 
  CROSS JOIN dvd_rentals.film B;
````
| film_reco   | film_total  | coverage   |
| ----------- | ----------- |----------- |
| 250         | 1000        |0.25000     |






## 4. What is the most popular top category?

### Steps:
- Use

````sql
Select
    category_name,
    COUNT(*) as count_category
FROM first_top_category_insights
GROUP BY category_name
ORDER BY count_cate DESC
LIMIT 1;
````
| category_name | count_category |
| --------------| -------------- |
| Animation     | 63             |





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
| category_name |
| --------------| 
| Documentary   |




## 6. What is the average percentile ranking for each customer in their top category
### Steps:
- Use

````sql
Select
    round(avg(percentile)::NUMERIC,3) as avg_percentile
From first_top_category_insights;
````
| avg_percentile |
| -------------- |
| 5.232          |




## 7. What is the cumulative distribution of the top 5 percentile values for the top category from the first_category_insights table
### Steps:
- Use

````sql
SELECT
  ROUND(percentile) as percentile,
  ROUND(100*CUME_DIST() OVER(ORDER BY ROUND(percentile))) AS cum_dist
FROM first_top_category_insights
GROUP BY 1
ORDER BY 1
LIMIT 5;
````
| percentile  | cum_dist    |
| ----------- | ----------- |
| 1           | 5           |
| 2           | 9           |
| 3           | 14          |
| 4           | 18          |
| 5           | 23          |



## 8. What is the median of the second category percentage of entire viewing history?
### Steps:
- Use

````sql
Select 
  percentile_cont(0.5) within Group(order by percentage_difference) as median
from second_category_insights;
````
| median      |       
| ----------- | 
| 13           | 



## 9. What is the 80th percentile of films watched featuring each customer’s favourite actor?
### Steps:
- Use

````sql
SELECT 
 PERCENTILE_CONT(0.8) within Group(order by rental_count) as eighth_rental_count
FROM top_actor_counts;
````
| eighth_rental_count | 
| ------------------- | 
| 5                   |


    
    
 ## 10. What was the average number of films watched by each customer
### Steps:
- Use

````sql
SELECT
    round(AVG(total_count)) as avg_num_film
From total_counts;
````
| avg_num_film |
| ------------ |
| 27           | 


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
|cat_1        | cat_2       | number_of_customer   |
| ----------- | ----------- |--------------------- |
| Animation   | Sci-Fi      |8                     |


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
| actor_name      | occurence |
| --------------- | ----------|
| GINA DEGENERES  | 19        |



 ## 13. How many films on average had customers already seen that feature their favourite actor
### Steps:
- Use

````sql
Select
    ROUND(AVG(rental_count)) as avg_film
FROM top_actor_counts;
````
| avg_film    | 
| ----------- | 
| 4           | 

