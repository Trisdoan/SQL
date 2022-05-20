# Case Study: People Analytics Case Study

CREDIT: Danny Ma.

You can view his course here: https://www.datawithdanny.com/


# Project Overview

Assist HR Analytica to construct datasets to answer basic reporting questions and also feed their bespoke People Analytics dashboards.

# Summarized Insights


## Data Cleaning

### 1. Creating a materialized view and cleaning dataset

#### Steps:
- Created schema named mv_employee. Because I did not want to adjust on original dataset
- Created materialized views for new schema.
- In materialized view mv_employees.department_employee, there were wrong input of data. So I added 18 years for columns: from_date, to_date.
- I did the same for materialized view department_manager, employee, salary, title

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


### 2. Created materialized view current_overview which contains current data of company.

#### Steps:
- Firstly, I used **CTE** to generate previous salary for each employees, which are called lag_salary.
- Then combine all tables together to generate full data by **INNER JOIN**.
- Finally, I used **DATE_PART()** to calculate calculate tenure years.

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

### 3. Create aggregation view at company level

#### Steps:
- Used **Sum() Over** to calculate percentage of employee count.
- Used aggregation funtions: **AVG**, **MIN**, **MAX**.
- Used **PERCENTILE_CONT** to calculate meduan and inter quartile for salary
- Used **STDEV** to calculate standard deviation.

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

### 4. Create aggregation view at department level

#### Steps:
- I did the same as above but replaced with gender and department.

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

### 5. Create aggregation view at title level

#### Steps:
- I did the same but replaced with gender and title.

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

### 6. Create benchmark views which compares average salary at company, gender, department, title level.

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



### 7. Created datasets which contains history records of employees

#### Steps:
- Firstly, I used **CTE** and **Subquery** to generate previous salary and rank for each events.
- Then I joined all related tables. In addition to that, I used **GREATEST** and **LEAST** to return latest and earliest date.
- The next step is to rank the events for each employee.
- Finally, I combined all datas, which includes salary change, and difference from average salary at department, title, gender levels.

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

## Ad-hoc requests about current status of company.

### 1. How many current employees have the equal longest tenure years in their current title?

#### Steps:
- I used **CTE** to generate longest tenure year for each title
- Filted by comparing to longest year.

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
<img src="People Analytics Case Study/images/1_!.png" width="200"/>



### 2. Which department has the least number of current employees?

#### Steps:
- Aggregated by **COUNT**

````sql
Select
  department,
  count(*) 
From mv_employees.current_overview
Group by department
Order by count(*);
````
#### Insight:


### 3. What is the largest difference between minimimum and maximum salary values for all current employees?

````sql
Select
  MAX(current_salary) - MIN(current_salary)
From mv_employees.current_overview;
````
#### Insight:



### 4. How many male employees are above the overall average salary value for the `Production` department?

#### Steps:
- Firstly, I created **CTE** and windown function **AVG()** to calculate average salary for department "Production"
- Used **CASE WHEN** filter and count who have salary above average salary

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
#### Insight:



### 5. Which title has the highest average salary for male employees?

#### Steps:
- Used **AVG** to calculate average current salary when filtering who are males
- Used **ORDER BY** to rank average salary

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
#### Insight:


### 6. Which department has the highest average salary for female employees?

#### Steps:
- I did the same as above but replaced filtering who are females.

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
#### Insight:


### 7. Which department has the most female employees?


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
- Firstly, I created **CTE** to calculate average salary for the highest paid department, filtered who are males.
- Then joined with table current_overview to count number of employees.

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

````sql
Select 
  Gender,
  ROUND(AVG(salary_percentage_change),4)
From mv_employees.current_overview
GROUP BY gender;
````
   
    
### 10. How many current employees have the equal longest overall time in their current positions (not in years)?

#### Steps:
- Firstly, I created **CTE** recalculate_cte to generate tenure years for each department_id
- Then another **CTE** max_time to find the longest tenure years
- Finally, joined those CTE together to calculate number of employees in the department which has longest tenure years.

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


## Ad-hoc requests about Employee Churn of company.

### 1. How many employees have left the company?

#### Steps:
- Filtered employees who have end_date different from 9999-01-01, an abstract date for current employees.

````sql
Select 
  COUNT(employee)
From mv_employees.historic_employee_records
WHERE event_order = 1
  AND end_date != '9999-01-01'
 ````
 
### 2. What percentage of churn employees were male?

#### Steps:
- Firstly, I created **CTE** to count number of churn employees, meaning who just left company
- Then filtered data who are males
- Finally, I used **CROSS JOIN** to calculate percentage of churn male employees compared to all churn employees.

````sql
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



### 3. Which title had the most churn?


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


### 4. Which department had the most churn?


````sql
Select 
  department,
  COUNT(employee) AS churn_employee
From mv_employees.historic_employee_records
WHERE event_order = 1
  AND end_date != '9999-01-01'
GROUP BY department
ORDER BY churn_employee DESC;
  
````


### 5. Which year had the most churn?

#### Steps:
- I used **EXTRACT** to get year from end_date column
- Then count employees who just left company

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



### 6. What was the average salary for each employees who has left the company rounded to the nearest integer?

#### Steps:
- 

````sql
Select ROUND(AVG(current_salary)) AS average_salary
From mv_employees.historic_employee_records
WHERE event_order = 1
  AND end_date != '9999-01-01';
````


### 7. What was the median total company tenure for each churn employee just bfore they left?

#### Steps:
- Used **PERCENTILE_CONT(0.5)** to find median of tenure year

````sql
Select 
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY company_tenure_year) as median
From mv_employees.historic_employee_records
WHERE event_order = 1
  AND end_date != '9999-01-01';
````

### 8. On average, how many different titles did each churn employee hold rounded to 1 decimal place?

#### Steps:

- Firstly, I created **CTE** to generate employees who have just left the company
- Then I used **ANTI JOIN** to join with historic_employee_records to count title

````sql
WITH churn_employee AS (  
  Select
    employee_id
  From mv_employees.historic_employee_records
  WHERE end_date != '9999-01-01'
    AND event_order = 1
),
  title_count AS (
  Select
    employee_id,
    COUNT(DISTINCT title) AS title_count
  From mv_employees.historic_employee_records A
  WHERE EXISTS(
        SELECT 1
        FROM churn_employee B
        WHERE A.employee_id = B.employee_id)
  GROUP BY employee_id
)
  Select
    ROUND(AVG(title_count),2)
  From title_count;
````



### 9. What was the average last pay increase for churn employees?


````sql
Select
    AVG(salary_change)
  From mv_employees.historic_employee_records
  WHERE end_date != '9999-01-01'
    AND event_order = 1
    AND salary_change > 0;
````




### 10. What percentage of churn employees had a pay decrease event in their last 5 events?

#### Steps:
- Firstly, I created **CTE** decreased_salary to find employees who had salary decreased in their last 5 events
- In this CTE, I used **CASE WHEN** and **MAX** to check who have decreased salary
- Then I used **ANTI JOIN** to deduplicate

````sql
WITH decreased_salary AS (
  Select
    employee_id,
    MAX( CASE
            WHEN event_name = 'Salary Decrease' THEN 1
            ELSE 0
          END) AS decrease_flag
  From mv_employees.historic_employee_records A 
  WHERE EXISTS (
          SELECT 1
          FROM mv_employees.historic_employee_records B 
          WHERE end_date != '9999-01-01'
              AND event_order = 1
              AND B.employee_id = A.employee_id)
    AND event_order <= 5
  GROUP BY employee_id
)
  SELECT
    ROUND((SUM(decrease_flag)/COUNT(*)::NUMERIC)*100,2)
  FROM decreased_salary;
````


    
 # Ad-hoc requests about management analysis of company.
 
 ## 1. How many managers are there currently in the company?

````sql
Select count(*)
From mv_employees.department_manager
WHERE to_date = '9999-01-01';
````



 ### 2. How many employees have ever been a manager?
 
#### Steps:
- Firstly, I fetched employees who had been a manager. I used **LEFT SEMI JOIN** to avoid duplication.
- Finally, I counted them from **CTE** just created.
````sql
WITH cte AS (
Select
  DISTINCT employee_id
FROM mv_employees.historic_employee_records A 
WHERE EXISTS (
      Select 1
      From mv_employees.department_manager B
      WHERE A.employee_id = B.employee_id
)
)
  Select
    COUNT(*)
  FROM cte;
````



 ### 3. On average - how long did it take for an employee to first become a manager from their the date they were originally hired in days?

#### Steps:
- Firstly, I fetched employees who had been a manager and their first_date when They became managers.
- Finally, I calculated average duration from the very date they came to company to date when they became managers

````sql
WITH first_date AS (
SELECT 
  employee_id,
  MIN(from_date) as first_date
FROM mv_employees.title
WHERE title = 'Manager'
GROUP BY employee_id
)
  Select 
    AVG(DATE_PART('DAY', B.first_date::TIMESTAMP -  A.hire_date::timestamp))
  From mv_employees.employee A 
  INNER JOIN first_date B 
      ON A.id = B.employee_id;
````


 ### 4. What was the most common titles that managers had just before before they became a manager?

#### Steps:
- Firstly, I found all previous tiltes of all employees
- Finally, I counted them from **CTE** just created, with filter that they are managers and previous_title IS NOT NULL.


````sql
WITH lag_title AS (
SELECT
  employee_id,
  title,
  LAG(title) OVER (PARTITION  BY employee_id ORDER BY from_date) AS previous_title
FROM mv_employees.title 
)
  Select
    previous_title,
    COUNT(*) as count_title
  FROM lag_title
  WHERE title = 'Manager'
    AND previous_title IS NOT NULL
  GROUP BY previous_title;
````


 ### 5. How many managers were first hired by the company as a manager?
 
 #### Steps:
- Firstly, I found all previous tiltes of all employees
- Finally, I counted them from **CTE** just created, with filter that they are managers and previous_title IS NULL.

````sql
WITH lag_jobs AS (
SELECT
  employee_id,
  title,
  LAG(title) OVER (PARTITION  BY employee_id ORDER BY from_date) AS previous_job
FROM mv_employees.title 
)
  Select
    COUNT(*) as count_title
  FROM lag_jobs
  WHERE title = 'Manager'
    AND previous_job IS  NULL;
````


 ### 6. On average - how much more do current managers make on average compared to all other employees rounded to the nearest dollar?
 
#### Steps:
- Firstly, I calculated average salary of all current managers.
- Then I calculated average salary of all employees who are not employees
- Finally, I calculated the differences between those above average.

````sql
WITH manager_cte AS (
    Select 
      AVG(current_salary) AS manager_salary
    From mv_employees.current_overview
    WHERE title = 'Manager'
),
  staff_cte AS (
    Select
      AVG(current_salary) AS staff_salary
    From mv_employees.current_overview
    WHERE title != 'Manager'
)
  Select
    ROUND(manager_salary - staff_salary)
  From staff_cte, manager_cte;
````


 ### 7. Which current manager has the most employees in their department?

#### Steps:
- Firstly, I counted employees for each deparment, excluding managers. I only fetched department which has most employees .
- Finally, I joined current_overview table with the cte just created. Then I extracted only manager


````sql
WITH employee_count_cte AS (
    SELECT 
      department,
      COUNT(*) AS employee_count
    FROM mv_employees.current_overview 
    WHERE title != 'Manager'
    GROUP BY department
    ORDER BY employee_count DESC
    LIMIT 1
)
    SELECT 
      employee,
      A.department
    FROM mv_employees.current_overview A 
    INNER JOIN employee_count_cte B
        ON A.department = B.department
    WHERE A.title = 'Manager';
````


 ### 8. What is the difference in employee count between the 3rd and 4th ranking departments by size?

#### Steps:
- Firstly, I counted employees for each deparment, including managers.
- The I created another **CTE** which contains rank of the size between departments and also their differences
- Finally, I extracted the size difference for the 3th department and 4th department

````sql
WITH dept_size AS (
SELECT
    department,
    COUNT(*) AS dept_size
FROM mv_employees.current_overview
GROUP BY department
),
  ranked_dept AS (
  Select
    department,
    RANK() OVER (ORDER BY dept_size DESC) AS ranked_,
    dept_size - LEAD(dept_size) OVER (ORDER BY dept_size DESC) AS size_diff
  From dept_size 
)
  Select *
  FROM ranked_dept
  WHERE ranked_ = 3;
````



