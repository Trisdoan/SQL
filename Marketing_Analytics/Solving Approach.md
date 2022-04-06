# Explained approach

View the complete syntax [here](https://github.com/katiehuangx/8-Week-SQL-Challenge/blob/main/Case%20Study%20%231%20-%20Danny's%20Diner/SQL%20Syntax/Danny's%20Diner.sql).

***

## How to come up with solution plan


## Solution plan
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


### 1. What is the total amount each customer spent at the restaurant?

````sql
SELECT s.customer_id, SUM(price) AS total_sales
FROM dbo.sales AS s
JOIN dbo.menu AS m
   ON s.product_id = m.product_id
GROUP BY customer_id; 
````

#### Steps:
- Use **SUM** and **GROUP BY** to find out ```total_sales``` contributed by each customer.
- Use **JOIN** to merge ```sales``` and ```menu``` tables as ```customer_id``` and ```price``` are from both tables.


#### Answer:
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |
| B           | 74          |
| C           | 36          |

- Customer A spent $76.
- Customer B spent $74.
- Customer C spent $36.

***
