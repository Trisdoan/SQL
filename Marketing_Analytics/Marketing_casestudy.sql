/*---------------------------------------------------
1. Create a base dataset and join all relevant tables
  * `complete_joint_dataset`
----------------------------------------------------*/

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

/*---------------------------------------------------
2. Calculate customer rental counts for each category
  * `category_counts`
----------------------------------------------------*/

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


/* ---------------------------------------------------
3. Aggregate all customer total films watched
  * `total_counts`
---------------------------------------------------- */

DROP TABLE IF EXISTS total_counts ;
CREATE TEMP TABLE total_counts AS(
    Select
        customer_id,
        SUM(rental_count) as total_count
    From category_counts
    GROUP BY 1
);


/* ---------------------------------------------------
4. Identify the top 2 categories for each customer
  * `top_categories`
---------------------------------------------------- */

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
    
/* ---------------------------------------------------
5. Calculate each category's aggregated average rental count
  * `average_category_count`
---------------------------------------------------- */

DROP TABLE IF EXISTS average_category_count ;
CREATE TEMP TABLE average_category_count AS(
    Select
        category_name,
        ---round down to nearest int
        FLOOR(AVG(rental_count)) as avg_category_count
    From category_counts
    GROUP BY category_name
);

/* ---------------------------------------------------
6. Calculate the percentile metric for each customer's
top category film count - be careful of where the
WHERE filter is applied!
  * `top_category_percentile`
  
=> show the required top N% customer insight. => answer: put you in top % of [category]
---------------------------------------------------- */

DROP TABLE IF EXISTS top_category_percentile;
CREATE TEMP TABLE top_category_percentile AS
  With cte AS(
    Select
        B.customer_id,
        B.category_name as top_category_name,
        B.ranked_category,
        A.rental_count,
        --- Input category_name from category_counts to compare to that of top_category table
        -- To get only 1st rank category
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
        
          
/* ---------------------------------------------------
7. Generate our first top category insights table using all previously generated tables
  * `first_top_category_insights`

=> Shows how many more film each customer watched more than average customer
---------------------------------------------------- */

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


/* ---------------------------------------------------
8. Generate the 2nd category insights
  * `second_category_insights`
  
=> Shows how much customer's watched film in each category make up all history of rental
---------------------------------------------------- */

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

/* -----------------------------
################################
### Category Recommendations ###
################################
--------------------------------*/


/* --------------------------------------------------------------
1. Generate a summarised film count table with the category
included, we will use this table to rank the films by popularity
  * `film_counts`
  
  => Generate total rental count, using film_id and title
---------------------------------------------------------------- */

DROP TABLE IF EXISTS film_counts ;
CREATE TEMP TABLE film_counts AS (
    Select DISTINCT
        film_id,
        title,
        category_name,
        COUNT(*) OVER(PARTITION BY film_id) AS rental_count
    From complete_data_table
);

/* ---------------------------------------------------
2. Create a previously watched films for the top 2
categories to exclude for each customer
  * `category_film_exclusions`
---------------------------------------------------- */

DROP TABLE IF EXISTS category_film_exclusions ;
CREATE TEMP TABLE category_film_exclusions AS(
    Select DISTINCT
        film_id,
        customer_id
    FROM complete_data_table
);


/* -------------------------------------------------------------------------
3. Finally perform an anti join from the relevant category films on the
exclusions and use window functions to keep the top 3 from each category
by popularity - be sure to split out the recommendations by category ranking
  * `category_recommendations`
---------------------------------------------------------------------------- */

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

/* -------------------
######################
### Actor Insights ###
######################
----------------------*/

/* ---------------------------------------------------
1. Create a new base dataset which has a focus on the actor instead of category
  * `actor_joint_table`
---------------------------------------------------- */

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

/* ---------------------------------------------------
2. Identify the top actor and their respective rental
count for each customer based off the ranked rental counts
* `top_actor_counts`
=> Showing: top actor for each customer_id
---------------------------------------------------- */
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

/* --------------------------
#############################
### Actor Recommendations ###
#############################
-----------------------------*/

/* ---------------------------------------------------
1. Generate total actor rental counts to use for film
popularity ranking in later steps
* `actor_film_counts`
---------------------------------------------------- */

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
    
/* -------------------------------------------------
2. Create an updated film exclusions table which
includes the previously watched films like we had
for the category recommendations - but this time we
need to also add in the films which were previously
recommended
  * `actor_film_exclusions`
---------------------------------------------------- */
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

/* -------------------------------------------------
3. Apply the same `ANTI JOIN` technique and use a
window function to identify the 3 valid film
recommendations for our customers
  * `actor_recommendations`
---------------------------------------------------- */

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
  

/* --------------------------
#############################
### Report ###
#############################
-----------------------------*/

/* -------------------------------------------------
TEMP TABLE needed for output:
  1. first_top_category_insights
  2. second_category_insights
  3. top_actor_counts
  4. category_recommendations
  5. actor_recommendations
---------------------------------------------------- */

/* -------------------------------------------------
Column needed: customer_id, cat_1, cat_1_reco_1, cat_1_reco_2,
cat_1_reco_3, cat_2, cat_2_reco_1, cat_2_reco_2, cat_2_reco_3, actor,
actor_reco_1, actor_reco_3, insight_cat_1, insight_cat_2,insight_actor
---------------------------------------------------- */

-- first_category insight
-- second_category insight
-- top_actor 
-- wide_category_recommendations 
-- wide_actor_recommendations 
-- final_output 

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

/* --------------------------
#############################
### Case Study Quiz ###
#############################
-----------------------------*/

/* -------------------------------------------------
Which film title was the most recommended for all customers?
---------------------------------------------------- */

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