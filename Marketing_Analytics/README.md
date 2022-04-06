# Case Study: Marketing Analytics
CREDIT: Danny Ma.

You can view his course here: https://www.datawithdanny.com/

## Table of Contents
- [Case Study Overview](#case-study-overview)
- [Requirements](#requirements)
- [Entity Relationship Diagram](#entity-relationship-diagram)
- [Solving problem and code](#solving-problem-and-code)

***

## Case Study Overview
We have been asked to support the customer analytics team at DVD Rental Co who have been tasked with generating the necessary data points required to populate specific parts of this first-ever customer email campaign.

The marketing team have shared with us a draft of the email they wish to send to their customers.

![marketing](https://user-images.githubusercontent.com/88806544/161837109-bb4b26a0-353e-4f2b-815f-7e85dfbd5ed0.png)


## Requirements

1. For each customer, we need to identify the top 2 categories for each customer based off their past rental history. These top categories will drive marketing creative images as seen in the travel and sci-fi examples in the draft email.
2. The marketing team has also requested for the 3 most popular films for each customer’s top 2 categories. Any customer which do not have any film recommendations for either category must be flagged out so the marketing team can exclude from the email campaign - this is of high importance!
3. For the 1st category, the marketing requires the following insights:
  - How many total films have they watched in their top category?
  - How many more films has the customer watched compared to the average DVD Rental Co customer?
  - How does the customer rank in terms of the top X% compared to all other customers in this film category?
4. For the second ranking category:
  - How many total films has the customer watched in this category?
  - What proportion of each customer’s total films watched does this count make?
5. Along with the top 2 categories, marketing has also requested top actor film recommendations where up to 3 more films are included in the recommendations list as well as the count of films by the top actor.

## Entity Relationship Diagram
![ERD](https://user-images.githubusercontent.com/88806544/161838741-8d4b8abe-5c74-4658-9fc9-ace1a7ead26b.png)

## Solving problem and code
<details>
<summary>
Click the link to see my code!
</summary>
  
1. [Approach to solve problem](https://github.com/Trisdoan/SQL/blob/3c28e69002be13a472f206a52342310f77bdc322/Marketing_Analytics/Solving%20Approach.md)
2. [Code](https://github.com/Trisdoan/SQL/blob/95ed34a91f105caac63dda2b372fe0c1079c2dec/Marketing_Analytics/code.sql)

</details>
  
***

