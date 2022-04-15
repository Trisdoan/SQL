# Explained approach

View the complete syntax [here](https://github.com/Trisdoan/SQL_Serious_SQL/blob/62f1110ec8346af7f1318840e84c00d9750b7316/Marketing_Analytics/code.sql).

***

## Solution plan
<details>
<summary>
Click here to view step-by-step plan
</summary>
  
1. Creating complete dataset which joins essential tables.
2. Calculate customer rental counts for each category.
3. Calculate total films each customer watched.
4. Identify top 2 categories for each customer.
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


### 2. Customer rental counts for each category

#### Steps:
- Use **Count** and **Group By** to answer how many film each customer watched per category.
- Use **Max** to find the latest rented date per each customer. It will be useful in later step where ranking.

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

### 3. Total films each customer watched

#### Steps:
- Use **Sum** and **Group By** to answer how many film each customer watched in total.

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

### 4. Top 2 categories for each customer

#### Steps:
- Use **CTE** and **Dense_Rank()** to rank categories based on rental count and latest rental date.
- Select records where categories in the top 2

````sql
DROP TABLE IF EXISTS top_categories ;
CREATE TEMP TABLE top_categories AS
  WITH cte AS(
    Select
        customer_id,
        category_name,
        rental_count,
        DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY rental_count DESC, 
                                                            latest_rental_date) 
        AS ranked_category
    From category_counts
)
    Select *
    From cte
    WHERE ranked_category <=2;
````

### 5. Average rental count per category

#### Steps:
- Use **AVG()** to answer how many did customers watched on each category on average.
- Use **Floor** to get the nearest integer.

````sql
DROP TABLE IF EXISTS average_category_count ;
CREATE TEMP TABLE average_category_count AS(
    Select
        category_name,
        ---round down to nearest int
        FLOOR(AVG(rental_count)) as avg_category_count
    From category_counts
    GROUP BY category_name
);
````

### 6. Average rental count per category

#### Steps:
- Use **PERCENT_RANK()** to calculate relative rank of each row's percentile
- Usse **CASE WHEN** to transform 0 percentile into 1 percentile

````sql
DROP TABLE IF EXISTS top_category_percentile;
CREATE TEMP TABLE top_category_percentile AS
  With cte AS(
    Select
        B.customer_id,
        B.category_name as top_category_name,
        B.ranked_category,
        A.rental_count,
        A.category_name,
        PERCENT_RANK() OVER (
            PARTITION BY A.category_name 
            ORDER BY A.rental_count DESC
          ) AS percentile_value
    From category_counts A 
    LEFT JOIN top_categories B 
        On A.customer_id = B.customer_id
)
      Select
        customer_id,
        category_name,
        rental_count,
        ranked_category,
        CASE
            WHEN ROUND(100*percentile_value) = 0 then 1 
            ELSE ROUND(100*percentile_value)
         END AS percentile
      From cte
      WHERE ranked_category = 1
          AND top_category_name = category_name;
````



### 7. First top category insights table 

#### Steps:
- Purpose of this table: create a table for top 1 category, which will be used later.

````sql
DROP TABLE IF EXISTS first_top_category_insights;
CREATE TEMP TABLE first_top_category_insights AS(
    Select
        A.customer_id,
        A.category_name,
        A.rental_count,
        A.rental_count - B.avg_category_count AS avg_comparision,
        A.percentile
    From top_category_percentile A 
    LEFT JOIN average_category_count B 
        On A.category_name = B.category_name
);
````

### 8. Second top category insights table 

#### Steps:
- Purpose of this table: create a table for top 2 category, which will be used later.

````sql
DROP TABLE IF EXISTS second_category_insights;
CREATE TEMP TABLE second_category_insights AS(
    Select
        A.customer_id,
        A.category_name,
        A.rental_count,
        ROUND(100* A.rental_count/B.total_count::NUMERIC) as percentage_difference
    From top_categories A 
    LEFT JOIN total_counts B 
        On A.customer_id = B.customer_id
    WHERE ranked_category = 2
);
````

### 9. Summarised film count table 


````sql
DROP TABLE IF EXISTS film_counts ;
CREATE TEMP TABLE film_counts AS (
    Select DISTINCT
        film_id,
        title,
        category_name,
        COUNT(*) OVER(PARTITION BY film_id) AS rental_count
    From complete_data_table
);
````

### 10. A previously watched film table


````sql
DROP TABLE IF EXISTS category_film_exclusions ;
CREATE TEMP TABLE category_film_exclusions AS(
    Select DISTINCT
        film_id,
        customer_id
    FROM complete_data_table
);
````


### 11. Perform an anti join from the relevant category films on the exclusions

#### Steps:
- Use **CTE** and **DENSE_RANK()** to rank recommendation film
- Use **ANTI JOIN** to exclude films which is alread watched

````sql
DROP TABLE IF EXISTS category_recommendations;
CREATE TEMP TABLE category_recommendations AS
  With ranked_cte AS(
    Select
        A.customer_id,
        A.category_name,
        A.ranked_category,
        B.film_id,
        B.title,
        B.rental_count,
        DENSE_RANK() OVER(PARTITION  BY customer_id, ranked_category
            ORDER BY B.rental_count DESC, B.title  
        ) AS reco_rank
    From top_categories A 
    INNER JOIN film_counts B 
        On A.category_name = B.category_name 
    WHERE  NOT EXISTS (
          Select 1
          From category_film_exclusions C 
          WHERE A.customer_id = C.customer_id
              AND B.film_id = C.customer_id
    )
)
Select 
  *
From ranked_cte
WHERE reco_rank <=3;
````



### 12. A new base dataset which has a focus on the actor


````sql
DROP TABLE IF EXISTS actor_joint_table;
CREATE TEMP TABLE actor_joint_table AS(
    Select
      A.customer_id,
      A.rental_id,
      A.rental_date,
      C.film_id,
      D.actor_id,
      CONCAT(E.first_name, ' ', E.last_name) AS actor_name,
      C.title
    From
      dvd_rentals.rental A
      INNER JOIN dvd_rentals.inventory B 
            On A.inventory_id = B.inventory_id
      INNER JOIN dvd_rentals.film C 
            On B.film_id = C.film_id
      INNER JOIN dvd_rentals.film_actor D 
            On C.film_id = D.film_id
      INNER JOIN dvd_rentals.actor E 
            On D.actor_id = E.actor_id
);
````


### 13.  Identify the top actor and their respective rental film count

#### Steps:
- Use **CTE** to count number of actors and rank actor based on numbers of film count

````sql
DROP TABLE IF EXISTS top_actor_counts;
CREATE TEMP TABLE top_actor_counts AS
 WITH actor_count AS(
    SELECT
      customer_id,
      actor_id,
      actor_name,
      COUNT(*) AS rental_count
    FROM
      actor_joint_table
    GROUP BY
      customer_id,
      actor_id,
      actor_name
  ),
  ranked_actor AS (
    Select
      actor_count.*,
      DENSE_RANK() OVER(
        PARTITION BY customer_id
        ORDER BY
          rental_count DESC,
          actor_name
      ) AS rank_actor
    FROM
      actor_count
)
    Select
        *
    From ranked_actor
    WHERE rank_actor = 1;
````

### 14. Generate total actor rental counts

#### Steps:
- Use **CTE** to count number of unique films

````sql
DROP TABLE IF EXISTS actor_film_counts;
CREATE TEMP TABLE actor_film_counts AS 
  WITH film_count AS (
    Select
      film_id,
      COUNT(DISTINCT rental_id) AS rental_count
    FROM
      actor_joint_table
    GROUP BY
      film_id
)
    Select DISTINCT
        A.film_id,
        A.actor_id,
        A.title,
        B.rental_count
    From actor_joint_table A
    LEFT JOIN film_count B 
        On A.film_id = B.film_id;
````

### 15. An updated film exclusions table
#### Steps:
- Use **UNION** to merge available films in total and films which are already recommended

````sql
DROP TABLE IF EXISTS actor_film_exclusions;
CREATE TEMP TABLE actor_film_exclusions AS
(
    Select DISTINCT
        customer_id,
        film_id
    From complete_data_table
)
UNION 
(
    Select DISTINCT
        customer_id,
        film_id
    From category_recommendations
);
````

### 16. Identify the 3 valid film recommendations
#### Steps:
- Use **CTE** and **DENSE_RANK()** to rank recommended films featuring favorite actors
- Use **ANTI JOIN** to exclude films which are already recommeneded and not rented

````sql
DROP TABLE IF EXISTS actor_recommendations ;
CREATE TEMP TABLE actor_recommendations AS
  WITH cte AS (
    Select
        A.customer_id,
        A.actor_name,
        A.rental_count,
        B.title,
        B.film_id,
        B.actor_id,
        DENSE_RANK() OVER(PARTITION BY A.customer_id ORDER BY B.rental_count DESC, B.title) as reco_rank
    FROM top_actor_counts A 
    INNER JOIN actor_film_counts B 
       On A.actor_id = B.actor_id
    WHERE NOT EXISTS (
        Select 1
        FROM actor_film_exclusions C 
        WHERE 
              A.customer_id = C.customer_id
            AND 
              B.film_id = C.film_id
))
    Select
        *
    FROM cte
    WHERE reco_rank <=3;
````
   
    
### 17. Final Report
#### Steps:
- Use **CTE** to merge all insight table
- Use **CONCAT** to create insight in string 

````sql
DROP TABLE IF EXISTS report_table;
CREATE TEMP TABLE report_table AS
  WITH first_category_insight AS(
    Select
      customer_id,
      category_name,
      CONCAT('You ','ve watched ' , rental_count,' ', category_name, ' film, 
      that''s ', avg_comparision, ' more than the DVD Rental Co average and puts you in the top ', percentile, '% of ', category_name ) as insight
    From first_top_category_insights
),
   second_category_insight AS(
      Select 
        customer_id,
        category_name,
        CONCAT('You ','ve watched ' , rental_count,' ', category_name, ' films,', 
      ' making up ',percentage_difference ,'% of your entire viewing history' ) as insight
      From second_category_insights
),
  top_actor AS (
      Select
          customer_id,
          actor_name,
          CONCAT('You''ve watched ', rental_count, ' films featuring ', actor_name, '. Here are some other films ', actor_name, 'stars in that might interest you!' ) as insight
      From top_actor_counts
),
    total_category_recommendations AS (
      Select
          customer_id,
          MAX(CASE WHEN ranked_category = 1 AND reco_rank =  1 THEN title END ) AS cat_1_reco_1,
          MAX(CASE WHEN ranked_category = 1 AND reco_rank =  2 THEN title END ) AS cat_1_reco_2,
          MAX(CASE WHEN ranked_category = 1 AND reco_rank =  3 THEN title END ) AS cat_1_reco_3,
          MAX(CASE WHEN ranked_category = 2 AND reco_rank =  1 THEN title END ) AS cat_2_reco_1,
          MAX(CASE WHEN ranked_category = 2 AND reco_rank =  2 THEN title END ) AS cat_2_reco_2,
          MAX(CASE WHEN ranked_category = 2 AND reco_rank =  3 THEN title END ) AS cat_2_reco_3
      From category_recommendations 
      GROUP BY customer_id
),
    total_actor_recommendations AS (
      Select
        customer_id,
        MAX(CASE WHEN reco_rank =  1 THEN title END ) AS actor_reco_1,
        MAX(CASE WHEN reco_rank =  2 THEN title END ) AS actor_reco_2,
        MAX(CASE WHEN reco_rank =  3 THEN title END ) AS actor_reco_3
      From actor_recommendations
      GROUP BY customer_id
),
    final_output AS (
      SELECT
          A.customer_id,
          C.category_name as cat_1,
          A.cat_1_reco_1,
          A.cat_1_reco_2,
          A.cat_1_reco_3,
          D.category_name as cat_2,
          A.cat_2_reco_1,
          A.cat_2_reco_2,
          A.cat_2_reco_3,
          E.actor_name,
          B.actor_reco_1,
          B.actor_reco_2,
          B.actor_reco_3,
          C.insight AS insight_1,
          D.insight AS insight_2,
          E.insight AS insight_actor
      FROM total_category_recommendations A 
      INNER JOIN total_actor_recommendations B 
        ON A.customer_id = B.customer_id
      INNER JOIN first_category_insight C
        ON A.customer_id = C.customer_id
      INNER JOIN second_category_insight D 
        ON A.customer_id = D.customer_id
      INNER JOIN top_actor E 
        ON A.customer_id = E.customer_id
)
    Select *
    FROM final_output;
````
***
