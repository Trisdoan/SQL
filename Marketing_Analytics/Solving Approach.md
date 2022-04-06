# Explained approach

View the complete syntax [here](https://github.com/katiehuangx/8-Week-SQL-Challenge/blob/main/Case%20Study%20%231%20-%20Danny's%20Diner/SQL%20Syntax/Danny's%20Diner.sql).

***

## How to come up with solution plan


## Solution plan
<details>
<summary>
Click here to view step-by-step plan
</summary>
  
1. Creating complete dataset which joins essential tables.
2. Calculate customer rental counts for each category.
3. Calculate total films each customer watched.
4. Identify top 2 categories for each customer
5. Calculate average rental count
6. Identify percentile for each customer's top category film count
7. Generate first top category insight => Shows how many more film each customer watched more than average customer
8. Generate second top category insight => Shows how much customer's watched film in each category make up all history of rental
9. Generate total rental film count
10. Create a table which contains previously watched films
11. Create a table which contains recommended films
12. Create a base dataset which contains actor information and rental films
13. Identify top actor and film count for each customer
14. Create a table which contains total film count, including actor information
15. Create a table which contains previously watched films and already recommended
16. Create a table which contains recommended films with actor information
17. Create final report for the marketing team.

</details>
  
***

### 1. Create complete dataset

````sql
DROP TABLE IF EXISTS complete_data_table;
CREATE TEMP TABLE complete_data_table  AS(
    Select
        A.customer_id,
        A.rental_id,
        A.rental_date,
        E.name as category_name,
        C.film_id,
        C.title
    From dvd_rentals.rental A 
    INNER JOIN dvd_rentals.inventory B 
        On A.inventory_id = B.inventory_id
    INNER JOIN dvd_rentals.film C 
        On B.film_id = C.film_id
    INNER JOIN dvd_rentals.film_category D 
        On C.film_id = D.film_id
    INNER JOIN dvd_rentals.category E 
        On D.category_id = E.category_id
);
````

#### Steps:
- Use **INNER JOIN** to merge ```rental```, ```inventory``` ,```film```,```film_category```and```category```.
- **INNER JOIN** and **LEFT JOIN** are them same. I did some tests to see whether there is a difference, which shows below.

<details>
<summary>
Click here to view results
</summary>
   
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

</details>


### 2. Customer rental counts for each category

````sql
DROP TABLE IF EXISTS category_counts ;
CREATE TEMP TABLE category_counts AS(
    Select
        customer_id,
        category_name,
        COUNT(*) as rental_count, 
        -- for ranking purspose
        MAX(rental_date) as latest_rental_date
    From complete_data_table
    GROUP BY 1,2
);
````

#### Steps:
- Use **Count** and **Group By** to answer how many film each customer watched per category.
- Use **Max** to find the latest rented date per each customer. It will be useful in later step where ranking.


### 3. Total films each customer watched

````sql
DROP TABLE IF EXISTS total_counts ;
CREATE TEMP TABLE total_counts AS(
    Select
        customer_id,
        SUM(rental_count) as total_count
    From category_counts
    GROUP BY 1
);
````

#### Steps:
- Use **Sum** and **Group By** to answer how many film each customer watched in total.

***
