# Case Study: People Analytics Case Study

CREDIT: Danny Ma.

You can view his course here: https://www.datawithdanny.com/


# Project Overview

Assist HR Analytica to construct datasets to answer basic reporting questions and also feed their bespoke People Analytics dashboards.

# Summarized Insights


## Contructing a report

### 1. Creating a materialized view and cleaning dataset

#### Steps:
- 

````sql
DROP SCHEMA IF EXISTS mv_employees CASCADE;
CREATE SCHEMA mv_employees;

-- department
DROP MATERIALIZED VIEW IF EXISTS mv_employees.department;
CREATE MATERIALIZED VIEW mv_employees.department AS
SELECT * FROM employees.department;

-- department employee
DROP MATERIALIZED VIEW IF EXISTS mv_employees.department_employee;
CREATE MATERIALIZED VIEW mv_employees.department_employee AS
SELECT
  employee_id,
  department_id,
  (from_date + interval '18 years')::DATE AS from_date,
  CASE
    WHEN to_date <> '9999-01-01' THEN (to_date + interval '18 years')::DATE
    ELSE to_date
    END AS to_date
FROM employees.department_employee;

-- department manager
DROP MATERIALIZED VIEW IF EXISTS mv_employees.department_manager;
CREATE MATERIALIZED VIEW mv_employees.department_manager AS
SELECT
  employee_id,
  department_id,
  (from_date + interval '18 years')::DATE AS from_date,
  CASE
    WHEN to_date <> '9999-01-01' THEN (to_date + interval '18 years')::DATE
    ELSE to_date
    END AS to_date
FROM employees.department_manager;

-- employee
DROP MATERIALIZED VIEW IF EXISTS mv_employees.employee;
CREATE MATERIALIZED VIEW mv_employees.employee AS
SELECT
  id,
  (birth_date + interval '18 years')::DATE AS birth_date,
  first_name,
  last_name,
  gender,
  (hire_date + interval '18 years')::DATE AS hire_date
FROM employees.employee;

-- salary
DROP MATERIALIZED VIEW IF EXISTS mv_employees.salary;
CREATE MATERIALIZED VIEW mv_employees.salary AS
SELECT
  employee_id,
  amount,
  (from_date + interval '18 years')::DATE AS from_date,
  CASE
    WHEN to_date <> '9999-01-01' THEN (to_date + interval '18 years')::DATE
    ELSE to_date
    END AS to_date
FROM employees.salary;

-- title
DROP MATERIALIZED VIEW IF EXISTS mv_employees.title;
CREATE MATERIALIZED VIEW mv_employees.title AS
SELECT
  employee_id,
  title,
  (from_date + interval '18 years')::DATE AS from_date,
  CASE
    WHEN to_date <> '9999-01-01' THEN (to_date + interval '18 years')::DATE
    ELSE to_date
    END AS to_date
FROM employees.title;

-- Index Creation
CREATE UNIQUE INDEX ON mv_employees.employee USING btree (id);
CREATE UNIQUE INDEX ON mv_employees.department_employee USING btree (employee_id, department_id);
CREATE INDEX        ON mv_employees.department_employee USING btree (department_id);
CREATE UNIQUE INDEX ON mv_employees.department USING btree (id);
CREATE UNIQUE INDEX ON mv_employees.department USING btree (dept_name);
CREATE UNIQUE INDEX ON mv_employees.department_manager USING btree (employee_id, department_id);
CREATE INDEX        ON mv_employees.department_manager USING btree (department_id);
CREATE UNIQUE INDEX ON mv_employees.salary USING btree (employee_id, from_date);
CREATE UNIQUE INDEX ON mv_employees.title USING btree (employee_id, title, from_date);

````


### 2. 

#### Steps:
- 

````sql
DROP  MATERIALIZED VIEW IF EXISTS mv_employees.current_overview CASCADE;
CREATE  MATERIALIZED VIEW mv_employees.current_overview AS 
With lag_salary AS (
  Select *
  From (
    Select
      employee_id,
      to_date,
      LAG(amount) OVER (PARTITION BY employee_id ORDER BY from_date) AS amount
    From mv_employees.salary
    ) all_salaries
    
  WHERE to_date = '9999-01-01'
),
  cte_complete_info AS (
    Select
      A.id AS employee_id,
      CONCAT_WS(' ',A.first_name,A.last_name) as employee,
      A.gender,
      A.hire_date,
      B.title,
      CONCAT_WS(' ',manager.first_name,manager.last_name) as manager,
      B.from_date as title_from_date,
      C.amount AS current_salary,
      D.amount AS lag_salary,
      F.dept_name as department,
      E.from_date as department_from_date
    FROM mv_employees.employee A 
    INNER JOIN mv_employees.title B 
        ON A.id = B.employee_id
    INNER JOIN mv_employees.salary C 
        ON A.id = C.employee_id
    INNER JOIN lag_salary D
        ON A.id = D.employee_id
    INNER JOIN mv_employees.department_employee E 
        ON A.id = E.employee_id 
    INNER JOIN mv_employees.department F
        ON E.department_id = F.id 
    INNER JOIN mv_employees.department_manager G
        ON E.department_id = G.department_id
    INNER JOIN mv_employees.employee as manager
        ON manager.id = G.employee_id
    WHERE C.to_date = '9999-01-01' 
        AND B.to_date = '9999-01-01' 
        AND E.to_date = '9999-01-01' 
        AND G.to_date = '9999-01-01' 
),
  final_output AS (
    Select
      employee_id,
      employee,
      gender,
      title,
      manager,
      current_salary,
      department,
      DATE_PART('year', now()) - DATE_PART('year', hire_date) AS company_tenure_year,
      DATE_PART('year', now()) - DATE_PART('year', title_from_date) AS title_tenure_year,
      DATE_PART('year', now()) - DATE_PART('year', department_from_date) AS department_tenure_year,
      ROUND(100*((current_salary - lag_salary)/lag_salary::NUMERIC),2) as salary_percentage_change
    From cte_complete_info
)
    Select *
    From final_output;
````

### 3. 

#### Steps:
- 

````sql
DROP VIEW IF EXISTS mv_employees.company_level CASCADE;
CREATE VIEW mv_employees.company_level AS 
  Select
    gender,
    COUNT(*) AS employee_count,
    ROUND(100*(COUNT(*)::NUMERIC/SUM(COUNT(*)) OVER())) AS employee_percentage,
    ROUND(AVG(company_tenure_year)) as company_tenure,
    ROUND(AVG(current_salary)) as avg_salary,
    ROUND(AVG(salary_percentage_change)) as avg_percentage_change,
    MIN(current_salary) as min_salary,
    MAX(current_salary) as max_salary,
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY current_salary) AS median_salary,
    PERCENTILE_CONT(0.75) WITHIN GROUP(ORDER BY current_salary) -
      PERCENTILE_CONT(0.25) WITHIN GROUP(ORDER BY current_salary) AS inter_quartile_salary,
    STDDEV(current_salary) AS std_salary
  From mv_employees.current_overview 
  GROUP BY gender;
````

### 4. 

#### Steps:
- 

````sql
DROP VIEW IF EXISTS mv_employees.department_level CASCADE;
CREATE VIEW mv_employees.department_level AS 
  Select
    gender,
    department,
    COUNT(*) AS employee_count,
    ROUND(100*(COUNT(*)::NUMERIC/SUM(COUNT(*)) OVER())) AS employee_percentage,
    ROUND(AVG(company_tenure_year)) as deparment_tenure,
    ROUND(AVG(current_salary)) as avg_salary,
    MIN(current_salary) as min_salary,
    MAX(current_salary) as max_salary,
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY current_salary) AS median_salary,
    PERCENTILE_CONT(0.75) WITHIN GROUP(ORDER BY current_salary) -
      PERCENTILE_CONT(0.25) WITHIN GROUP(ORDER BY current_salary) AS inter_quartile_salary,
    STDDEV(current_salary) AS std_salary
  From mv_employees.current_overview 
  GROUP BY gender, department;
````

### 5. 

#### Steps:
- 
````sql
DROP VIEW IF EXISTS mv_employees.title_level CASCADE;
CREATE VIEW mv_employees.title_level AS 
  Select
    gender,
    title,
    COUNT(*) AS employee_count,
    ROUND(100*(COUNT(*)::NUMERIC/SUM(COUNT(*)) OVER()),2) AS employee_percentage,
    ROUND(AVG(company_tenure_year)) as title_tenure,
    ROUND(AVG(current_salary)) as avg_salary,
    MIN(current_salary) as min_salary,
    MAX(current_salary) as max_salary,
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY current_salary) AS median_salary,
    PERCENTILE_CONT(0.75) WITHIN GROUP(ORDER BY current_salary) -
      PERCENTILE_CONT(0.25) WITHIN GROUP(ORDER BY current_salary) AS inter_quartile_salary,
    STDDEV(current_salary) AS std_salary
  From mv_employees.current_overview 
  GROUP BY gender, title);
````

### 6. 

#### Steps:
- 

````sql
DROP VIEW IF EXISTS mv_employees.company_tenure_benchmark CASCADE;
CREATE VIEW mv_employees.company_tenure_benchmark AS 
SELECT
  company_tenure_year,
  ROUND(AVG(current_salary),2) as tenure_benchmark_salary
FROM mv_employees.current_overview
GROUP BY company_tenure_year;

DROP VIEW IF EXISTS mv_employees.gender_benchmark CASCADE;
CREATE VIEW mv_employees.gender_benchmark AS 
SELECT
  gender,
  ROUND(AVG(current_salary),2) as gender_benchmark_salary
FROM mv_employees.current_overview
GROUP BY gender;

DROP VIEW IF EXISTS mv_employees.department_benchmark CASCADE;
CREATE VIEW mv_employees.department_benchmark AS 
SELECT
  department,
  ROUND(AVG(current_salary),2) as department_benchmark_salary
FROM mv_employees.current_overview
GROUP BY department;


DROP VIEW IF EXISTS mv_employees.title_benchmark CASCADE;
CREATE VIEW mv_employees.title_benchmark AS 
SELECT
  title,
  ROUND(AVG(current_salary),2) as title_benchmark_salary
FROM mv_employees.current_overview
GROUP BY title;
````



### 7. 

#### Steps:
- 

````sql
DROP MATERIALIZED VIEW IF EXISTS mv_employees.historic_employee_records;
CREATE MATERIALIZED VIEW mv_employees.historic_employee_records AS
WITH lag_amount AS (
SELECT
    employee_id,
    amount
  FROM (
    SELECT
      employee_id,
      to_date,
      LAG(amount) OVER (
        PARTITION BY employee_id
        ORDER BY from_date
      ) AS amount,
      ROW_NUMBER() OVER (
        PARTITION BY employee_id
        ORDER BY to_date DESC
      ) AS record_rank
    FROM mv_employees.salary
  ) all_salaries
  WHERE record_rank = 1
),
  cte_join AS (
    Select
      A.id AS employee_id,
      A.birth_date,
      DATE_PART('year', now()) -
        DATE_PART('year', A.birth_date) as employee_age,
      CONCAT_WS(' ',A.first_name,A.last_name) as employee,
      A.gender,
      A.hire_date,
      B.title,
      CONCAT_WS(' ',manager.first_name,manager.last_name) as manager,
      B.from_date as title_from_date,
      C.amount AS current_salary,
      D.amount AS latest_previous_salary,
      F.dept_name as department,
      E.from_date as department_from_date,
      DATE_PART('year', now()) - DATE_PART('year', A.hire_date) AS company_tenure_year,
      DATE_PART('year', now()) - DATE_PART('year', B.from_date) AS title_tenure_year,
      DATE_PART('year', now()) - DATE_PART('year', E.from_date) AS department_tenure_year,
      DATE_PART('month', AGE(now(), B.from_date)) as title_tenure_month,
      GREATEST(
        B.from_date,
        C.from_date,
        E.from_date,
        G.from_date
      ) AS start_date,
      LEAST(
        B.to_date,
        C.to_date,
        E.to_date,
        G.to_date
      ) as end_date
    FROM mv_employees.employee A
    INNER JOIN mv_employees.title B
        ON A.id = B.employee_id
    INNER JOIN mv_employees.salary C
        ON A.id = C.employee_id
    INNER JOIN lag_amount D
        ON A.id = D.employee_id
    INNER JOIN mv_employees.department_employee E
        ON A.id = E.employee_id
    INNER JOIN mv_employees.department F
        ON E.department_id = F.id
    INNER JOIN mv_employees.department_manager G
        ON E.department_id = G.department_id
    INNER JOIN mv_employees.employee as manager
        ON manager.id = G.employee_id
),
  ordered_event AS(
    Select
      employee_id,
      employee,
      birth_date,
      employee_age,
      gender,
      hire_date,
      title,
      LAG(title) OVER T AS previous_title,
      current_salary,
      latest_previous_salary,
      LAG(current_salary) OVER T AS previous_salary,
      manager,
      LAG(manager) OVER T AS previous_manager,
      department,
      LAG(department) OVER T AS previous_department,
      company_tenure_year,
      title_tenure_year,
      department_tenure_year,
      title_tenure_month,
      start_date,
      end_date,
      ROW_NUMBER() OVER(PARTITION BY employee_id ORDER BY start_date DESC) as event_order
    From cte_join
    WHERE start_date < end_date
    WINDOW
      T AS (PARTITION BY employee_id ORDER BY start_date)
),
  final_out AS (
    Select
      base.employee_id,
      base.employee,
      base.birth_date,
      base.employee_age,
      base.gender,
      base.hire_date,
      base.title,
      base.previous_title,
      base.current_salary,
      base.latest_previous_salary,
      base.previous_salary,
      base.manager,
      base.previous_manager,
      base.department,
      base.previous_department,
      base.company_tenure_year,
      base.title_tenure_year,
      base.department_tenure_year,
      base.title_tenure_month,
      base.event_order,
      
      CASE
        WHEN event_order = 1 THEN 
          ROUND(100*((base.current_salary - base.latest_previous_salary)/base.latest_previous_salary::NUMERIC),2)
        ELSE NULL 
      END AS latest_salary_percentage_change,
      CASE
        WHEN base.current_salary > base.latest_previous_salary THEN 'Salary Increase'
        WHEN base.current_salary < base.latest_previous_salary THEN 'Salary Decrease'
        WHEN base.previous_title <> base.title THEN 'Titlte changed'
        WHEN base.previous_manager <> base.manager THEN 'Reporting line changed'
        WHEN base.previous_department <> base.department THEN 'Department changed'
        ELSE NULL
      END AS event_name,
      
      ROUND(base.current_salary - base.latest_previous_salary) AS salary_change,
      ROUND((base.current_salary - base.latest_previous_salary)/ base.latest_previous_salary::NUMERIC) AS salary_change_percentage,
      
      ROUND(tenure_benchmark_salary) AS tenure_benchmark_salary,
      ROUND(100*(base.current_salary - tenure_benchmark_salary)/tenure_benchmark_salary::NUMERIC) AS tenure_comparison,
      
      ROUND(department_benchmark_salary) AS department_benchmark_salary,
      ROUND(100*(base.current_salary - department_benchmark_salary)/department_benchmark_salary::NUMERIC) AS department_comparison,
      
      ROUND(gender_benchmark_salary) AS gender_benchmark_salary,
      ROUND(100*(base.current_salary - gender_benchmark_salary)/gender_benchmark_salary::NUMERIC) AS gender_comparison,
      
      ROUND(title_benchmark_salary) AS title_benchmark_salary,
      ROUND(100*(base.current_salary - title_benchmark_salary)/title_benchmark_salary::NUMERIC) AS title_comparison,
      base.start_date,
      base.end_date
    From ordered_event as base
    INNER JOIN mv_employees.company_tenure_benchmark A
      ON base.company_tenure_year = A.company_tenure_year::FLOAT
    INNER JOIN mv_employees.department_benchmark B
      ON base.department = B.department
    INNER JOIN mv_employees.gender_benchmark C 
      ON base.gender = C.gender
    INNER JOIN mv_employees.title_benchmark D 
      ON base.title = D.title
)
  Select *
  From final_out;
````

## Ad-hoc requests about 

### 1. How many current employees have the equal longest tenure years in their current title?

#### Steps:
- 

````sql
WITH cte AS (
  Select 
    title,
    MAX(title_tenure_year) as longest
  FROM mv_employees.current_overview 
  GROUP BY title
)

Select 
  count(distinct employee) as count_employee
FROM mv_employees.current_overview A, cte
WHERE title_tenure_year = longest;
````

### 2. Which department has the least number of current employees?


````sql
Select
  department,
  count(*) 
From mv_employees.current_overview
WHERE department in ('Production', 'Sales', 'Development','Customer Service')
Group by department
Order by count(*);
````

### 3. What is the largest difference between minimimum and maximum salary values for all current employees?


````sql
Select
  MAX(current_salary) - MIN(current_salary)
From mv_employees.current_overview;
````


### 4. How many male employees are above the overall average salary value for the `Production` department?

#### Steps:
- 

````sql
WITH cte AS (
Select
  employee,
  gender,
  current_salary,
  AVG(current_salary) OVER () AS average_salary
From mv_employees.current_overview
WHERE  department = 'Production'

)
  Select
    SUM(
      CASE
        WHEN current_salary > average_salary  THEN 1
        ELSE 0
      END) AS total_employee
  From cte
  WHERE  gender = 'M'
AND current_salary > average_salary ;
````



### 5. Which title has the highest average salary for male employees?


````sql
Select
    title,
    AVG(current_salary)
  From mv_employees.current_overview
  WHERE gender = 'M'
  GROUP BY title
  ORDER BY AVG(current_salary) DESC
  Limit 1;
````


### 6. Which department has the highest average salary for female employees?

#### Steps:
- 
````sql
Select
    department,
    AVG(current_salary)
  From mv_employees.current_overview
  WHERE gender = 'F'
  GROUP BY department
  ORDER BY AVG(current_salary) DESC
  Limit 1;
````

### 7. Which department has the most female employees?

#### Steps:
- 
````sql
Select
  department,
  COUNT(employee)
from mv_employees.current_overview
WHERE gender = 'F'  
GROUP BY department
ORDER BY COUNT(employee) desc;
````

### 8. What is the gender ratio in the department which has the highest average male salary and what is the average male salary value rounded to the nearest integer?

#### Steps:
- 

````sql
WITH cte AS (
  Select
    department,
    ROUND(AVG(current_salary),2) as average_salary
  FROM mv_employees.current_overview
  WHERE gender = 'M'
  GROUP BY department
  ORDER BY average_salary DESC 
  LIMIT 1
)
  Select
    gender,
    average_salary,
    COUNT(*) AS number_employee
  From mv_employees.current_overview A 
  INNER JOIN cte B 
    ON A.department = B.department
  GROUP BY gender, average_salary;
````

### 9. HR Analytica want to change the average salary increase percentage value to 2 decimal places. What should the new value be for males for the company level dashboard?

#### Steps:
- 
````sql
Select 
  Gender,
  ROUND(AVG(salary_percentage_change),4)
From mv_employees.current_overview
GROUP BY gender;
````
   
    
### 10. How many current employees have the equal longest overall time in their current positions (not in years)?

#### Steps:
- 

````sql
WITH recalculate_cte AS (
Select  
  department_id,
  DATE_PART('day', now()) - DATE_PART('day', from_date) as tenure
From mv_employees.department_employee
),
  max_time AS (
  Select  
  department_id,
  MAX(DATE_PART('day', now()) - DATE_PART('day', from_date)) as max_tenure
  From mv_employees.department_employee
  GROUP BY department_id
)
  Select
    COUNT(*)
  From recalculate_cte A 
  INNER JOIN max_time B 
    ON A.department_id = B.department_id
  WHERE tenure = max_tenure;
````


## Ad-hoc requests about ## Questions from marketing team

### 1. How many employees have left the company?

#### Steps:
- Use **Union Join** to combine 2 recommendation tables created

````sql
Select COUNT(employee)
From mv_employees.historic_employee_records
WHERE event_order = 1
  AND end_date != '9999-01-01'
  
-- What percentage of churn employees were male?

WITH cte AS (
    Select
      COUNT(employee) AS churn_employee_total
    From mv_employees.historic_employee_records
    WHERE event_order = 1
      AND end_date != '9999-01-01'
),
  male_cte AS (
  Select 
    COUNT(employee) AS churn_employee_male_total
  From mv_employees.historic_employee_records
  WHERE event_order = 1
      AND end_date != '9999-01-01'
      AND gender = 'M'
)
  Select
    ROUND(churn_employee_male_total/churn_employee_total::NUMERIC,2)
  FROM male_cte 
  CROSS JOIN cte;
````

| title          | reco_count  |
| ---------------| ----------- |
|JUGGLER HARDLY  | 145         |



### 2. Which title had the most churn?

#### Steps:
- U

````sql
Select 
  title,
  COUNT(employee) AS churn_employee
From mv_employees.historic_employee_records
WHERE event_order = 1
  AND end_date != '9999-01-01'
GROUP BY title
ORDER BY churn_employee DESC;
````
| count_customers |
| ----------------| 
| 599             |


### 3. Which department had the most churn?

#### Steps:
- 

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






### 4. Which year had the most churn?

#### Steps:
- U

````sql
Select 
  EXTRACT('year' from end_date) as yr,
  COUNT(employee) AS churn_employee
From mv_employees.historic_employee_records
WHERE event_order = 1
  AND end_date != '9999-01-01'
GROUP BY EXTRACT('year' from end_date)
ORDER BY churn_employee DESC;
````
| category_name | count_category |
| --------------| -------------- |
| Animation     | 63             |





### 5. What was the average salary for each employees who has left the company rounded to the nearest integer?

#### Steps:
- 

````sql
Select ROUND(AVG(current_salary)) AS average_salary
From mv_employees.historic_employee_records
WHERE event_order = 1
  AND end_date != '9999-01-01';
````
| category_name |
| --------------| 
| Documentary   |




### 6. What was the median total company tenure for each churn employee just bfore they left?

#### Steps:
- Use **AVG** to calculate average percentile for top categories 

````sql
Select 
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY company_tenure_year) as median
From mv_employees.historic_employee_records
WHERE event_order = 1
  AND end_date != '9999-01-01';
````
| avg_percentile |
| -------------- |
| 5.232          |




### 7. What is the cumulative distribution of the top 5 percentile values for the top category from the first_category_insights table

#### Steps:

- Use **CUME_DIST** to calculate cumulative distribution of top 5 percentile categories.

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



### 8. What is the median of the second category percentage of entire viewing history?

#### Steps:
- Use **PERCENTILE_CONT** to find median of viewing history

````sql
Select 
  percentile_cont(0.5) within Group(order by percentage_difference) as median
from second_category_insights;
````
| median      |       
| ----------- | 
| 13           | 



### 9. What is the 80th percentile of films watched featuring each customer’s favourite actor?

#### Steps:
- Use **PERCENTILE_CONT** to calculate 80th percentile of top actors

````sql
SELECT 
 PERCENTILE_CONT(0.8) within Group(order by rental_count) as eighth_rental_count
FROM top_actor_counts;
````
| eighth_rental_count | 
| ------------------- | 
| 5                   |


    
    
 ### 10. What was the average number of films watched by each customer

````sql
SELECT
    round(AVG(total_count)) as avg_num_film
From total_counts;
````
| avg_num_film |
| ------------ |
| 27           | 


 ### 11. What is the top combination of top 2 categories and how many customers if the order is relevant

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


 ### 12. Which actor was the most popular for all customers?

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



 ### 13. How many films on average had customers already seen that feature their favourite actor

````sql
Select
    ROUND(AVG(rental_count)) as avg_film
FROM top_actor_counts;
````
| avg_film    | 
| ----------- | 
| 4           | 


***
