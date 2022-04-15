# Solving problem

## 1. What is the total amount each customer spent at the restaurant?

### Steps:
- Use 
- 
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
- Use 


````sql
Select
    customer_id,
    Count(distinct order_date) as days 
From dannys_diner.sales
Group by customer_id 
Order by days  DESC;

````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |


## 3. What was the first item from the menu purchased by each customer?

### Steps:
- Use

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
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |


## 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

### Steps:
- Use

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
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |


## 5. Which item was the most popular for each customer?

### Steps:
- Use

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
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |




## 6. Which item was purchased first by the customer after they became a member?

### Steps:
- Use

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
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |



## 7. Which item was purchased just before the customer became a member?
### Steps:
- Use

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
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |


## 8. What is the total items and amount spent for each member before they became a member?
### Steps:
- Use

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
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |



## 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier. How many points would each customer have?
### Steps:
- Use

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
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |



## 10. In the first week after a customer joins the program(including their join date),they earn 2x points on all items. Not just sushi, how many points do customer A and B have at the end of January?
### Steps:
- Use

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
ORDER BY customer_id:
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |

| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |


 ## 11. Danny also requires further information about the ranking of customer products, but he purposely does not need the ranking for non-member purchases so he expects null ranking values for the records when customers are not yet part of the loyalty program.
### Steps:
- Use

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
From  all_info;
````
| customer_id | total_sales |
| ----------- | ----------- |
| A           | 76          |
