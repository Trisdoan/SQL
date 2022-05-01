# Case Study: Danny Dinner
CREDIT: Danny Ma.

You can view his challenge here: https://8weeksqlchallenge.com/case-study-1/

## Case Study Overview
Help the owner of the restauntant to generate some datasets so his team can easily inspect the data without needing to use SQL.

**1. Visiting patterns**

**2. Amount customers have spent**

**3. Top favorite products**

## Summarized Insights

1. So far, **customer A spent the most**, followed by customer B and C
2. However, **customer B visited the restaurant quite often**.
3. Customer **A and C seem like ramen** when it was the top 1 item purchased. While **customer B liked all dishes equally**.
4. After becoming member, customer A purchased curry, while customer B purchased sushi. **Customer C has not been a member yet**.


## Techniques I used:
1. CTE
2. Windown function: ROW_NUMBER, RANK()
3. Aggregate functions: SUM, COUNT
4. CASE WHEN

## 1. What is the total amount each customer spent at the restaurant?

### Steps:
- Use **LEFT JOIN** to find all sales for each customers
- Use **SUM** to calculate total sales per customers


````sql
Select
    customer_id,
    SUm(B.price) as total_sales
From dannys_diner.sales A 
LEFT JOIN dannys_diner.menu B 
    On A.product_id = B.product_id
Group by customer_id
Order by total_sales DESC;
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |
| B           | 74          |
| C           | 36          |



## 2. How many days has each customer visited the restaurant?

### Steps:
- Use **COUNT AND GROUP BY** to find how many days each customers visited


````sql
Select
    customer_id,
    Count(distinct order_date) as days 
From dannys_diner.sales
Group by customer_id 
Order by days  DESC;

````
| customer_id | days        |
| ----------- | ----------- |
| B           | 6           |
| A           | 4           |
| C           | 2           |



## 3. What was the first item from the menu purchased by each customer?

### Steps:
- Use **CTE** and **RANK()** to rank order by each customers
- Use **SELECT DISTINCT** to find the first item purchased

````sql
With ranked_order AS (
Select
    customer_id,
    RANK() OVER(PARTITION BY customer_id ORDER BY order_date) as order_rank,
    product_name
From dannys_diner.sales A 
JOIN dannys_diner.menu B 
    On A.product_id = B.product_id
)
  Select DISTINCT
      customer_id,
      product_name
  From ranked_order
  Where order_rank = 1;
````
| customer_id | product_name|
| ----------- | ----------- |
| A           | curry       |
| A           | sushi       |
| B           | curry       |
| C           | ramen       |




## 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

### Steps:
- Use **LEFT JOIN** to find all number of products
- Use **GROUP BY** and **ORDER** to find the most item purchased

````sql
Select
    product_name,
    COunt(*) as count_sales
From dannys_diner.sales A 
Left join dannys_diner.menu B 
    On A.product_id = B.product_id
GROUP BY A.product_id, product_name
ORDER BY count_sales Desc
Limit 1;
````
| product_name | count_sales |
| ------------ | ----------- |
| ramen        | 8           |




## 5. Which item was the most popular for each customer?

### Steps:
- Use **CTE** and **RANK()** to find and rank all items purchased by each customers
- Get only the first rank of each customers

````sql
WITH cte AS (
Select
    customer_id,
    A.product_id,
    product_name,
    COunt(*) as count_sales,
    RANK() OVER(PARTITION BY customer_id ORDER BY  COunt(*) DESC) as sales_rank 
From dannys_diner.sales A 
Left join dannys_diner.menu B 
    On A.product_id = B.product_id
GROUP BY customer_id, A.product_id, product_name
)
  Select
      customer_id,
      product_name,
      count_sales
  From cte
  WHERE sales_rank = 1
  Order by customer_id;
````
| customer_id | product_name | count_sales |
| ----------- | ------------ | ----------- |
| A           | ramen        |3            |
| B           | sushi        |2            |
| B           | ramen        |2            |
| B           | curry        |2            |
| C           | ramen        |3            |





## 6. Which item was purchased first by the customer after they became a member?

### Steps:
- Use **CTE** and **RANK()*** to rank each time customers purchased
- Use **LEFT JOIN** to join back to table menu to get product_name

````sql
With cte AS (
Select
    A.customer_id,
    product_id,
    join_date,
    order_date,
    order_date -join_date AS number_days,
    RANK() OVER(PARTITION BY A.customer_id ORDER BY order_date -join_date, order_date) as day_rank
From dannys_diner.members A 
LEFT JOIN dannys_diner.sales B 
    On A.customer_id = B.customer_id
WHERE order_date -join_date >=0
)
Select
    customer_id,
    order_date,
    product_name
From cte A 
LEFT JOIN dannys_diner.menu B 
    On A.product_id = B.product_id
Where day_rank = 1
ORDER BY customer_id;
````
| customer_id | order_date  |product_name |
| ----------- | ----------- |-----------  |
| A           | 2021-01-07  |curry        |
| B           | 2021-01-11  |sushi        |





## 7. Which item was purchased just before the customer became a member?

### Steps:
- Use **CTE** and **RANK()*** to rank each time customers purchased
- Use **LEFT JOIN** to join back to table menu to get product_name

````sql
With cte AS (
Select
    A.customer_id,
    product_id,
    join_date,
    order_date,
    order_date -join_date AS number_days,
    RANK() OVER(PARTITION BY A.customer_id ORDER BY order_date -join_date DESC, order_date) as day_rank
From dannys_diner.members A 
LEFT JOIN dannys_diner.sales B 
    On A.customer_id = B.customer_id
WHERE order_date -join_date <0
)
Select
    customer_id,
    order_date,
    product_name
From cte A 
LEFT JOIN dannys_diner.menu B 
    On A.product_id = B.product_id
Where day_rank = 1
ORDER BY customer_id;
````
| customer_id | order_date  |product_name |
| ----------- | ----------- |-----------  |
| A           | 2021-01-01  |sushi        |
| A           | 2021-01-01  |curry        |
| B           | 2021-01-04  |sushi        |


## 8. What is the total items and amount spent for each member before they became a member?
### Steps:
- Use **LEFT JOIN** to get information of each items when they were purchased
- Use **WHERE** to get items only order_date < join_date

````sql
Select
    A.customer_id,
    Count(distinct A.product_id) as total_unique_product,
    Sum(B.price) as total_price
From dannys_diner.sales A 
LEFT JOIN dannys_diner.menu B 
    On A.product_id = B.product_id
LEFT JOIN dannys_diner.members C 
    On A.customer_id = C.customer_id
Where  A.order_date < C.join_date
Group  by A.customer_id;
````
| customer_id | total_unique_product|total_price  |
| ----------- | ------------------- |-----------  |
| A           | 2                   |25           |
| A           | 2                   |40           | 



## 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier. How many points would each customer have?

### Steps:
- Use **CASE WHEN** to double the point for product "sushi"

````sql
Select
    customer_id,
    SUM(Case
        When product_name = 'sushi' then 10*2*price
        Else 10*price 
    End) AS total_point
From dannys_diner.sales A 
LEFT JOIN dannys_diner.menu B 
    ON A.product_id = B.product_id
Group by customer_id;
````
| customer_id | total_point |
| ----------- | ----------- |
| B           | 940         |
| C           | 360         |
| A           | 860         |



## 10. In the first week after a customer joins the program(including their join date),they earn 2x points on all items. Not just sushi, how many points do customer A and B have at the end of January?

### Steps:
- Use **CASE WHEN** to double the point for product "sushi" and first period when they became membership

````sql
Select
  A.customer_id,
  SUM(
    CASE
      When product_name = 'sushi' then 2*10*price
      WHEN order_date <= (join_date::DATE +7) and order_date >= join_date::DATE then 2*10*price
      ELSE 10*price
    END) as total_point
From dannys_diner.sales A
Join dannys_diner.menu B 
    On A.product_id = B.product_id
Join dannys_diner.members C 
    On A.customer_id = C.customer_id
WHERE order_date <= '2021-01-31'::DATE
Group by A.customer_id
ORDER BY customer_id;
````
| customer_id | total_point |
| ----------- | ----------- |
| A           | 1370        |
| B           | 940         |


 ## 11. Danny also requires further information about the ranking of customer products, but he purposely does not need the ranking for non-member purchases so he expects null ranking values for the records when customers are not yet part of the loyalty program.
 
### Steps:
- Use **CREATE TEMP TABLE** to create a dataset which contains item information, including boolean column "member"
- Use **CASE WHEN** and **DENSE_RANK()** to rank products based on order_date 

````sql
DROP TABLE IF EXISTS all_info;
CREATE TEMP TABLE all_info AS (
Select
    A.customer_id,
    A.order_date,
    B.product_name,
    B.price,
    Case
      When A.order_date >= C.join_date then 'YES'
      ELSE 'NO'
    END AS member
From dannys_diner.sales A 
JOIN dannys_diner.menu B 
    On A.product_id = B.product_id
LEFT JOIN dannys_diner.members C 
    On A.customer_id = C.customer_id
Order by A.customer_id,
         A.order_date
);

Select 
    *,
    CASE
      WHEN member = 'NO' then null
      ELSE DENSE_RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date)
    END AS ranking
From  all_info
LIMIT 2;
````
| customer_id | order_date  | product_name | price | member | ranking |
| ----------- | ----------- | -----------  | ----- | ------ |-------- |
| A           | 2021-01-01  |sushi         |10     |NO      |null     |
| A           | 2021-01-01  |curry         |15     |NO      |null     |
