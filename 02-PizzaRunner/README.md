# Case Study #2 - Pizza Runner

![header_img](assets/header_img.png)

<br>

# Table of Contents

* [1 Introduction](#introduction)
    * [1.1 Entity Relationship Diagram](#entity-relationship-diagram)
* [2 Problem Statement](#problem-statement)


* [Schema]()
* [Queries]()
* [Answers]()

<br>

# Introduction

Danny was scrolling through his Instagram feed when something really caught his eye - “80s Retro Styling and Pizza Is The Future!”

Danny was sold on the idea, but he knew that pizza alone was not going to help him get seed funding to expand his new Pizza Empire - so he had one more genius idea to combine with it - he was going to Uberize it - and so Pizza Runner was launched!

Danny started by recruiting “runners” to deliver fresh pizza from Pizza Runner Headquarters (otherwise known as Danny’s house) and also maxed out his credit card to pay freelance developers to build a mobile app to accept orders from customers.

## Entity Relationship Diagram
![ERD](assets/ERD.png)

<br>

# Problem Statement

Because Danny had a few years of experience as a data scientist - he was very aware that data collection was going to be critical for his business’ growth.

He has prepared for us an entity relationship diagram of his database design but requires further assistance to clean his data and apply some basic calculations so he can better direct his runners and optimise Pizza Runner’s operations.

This case study has LOTS of questions - they are broken up by area of focus including:

* Pizza Metrics
* Runner and Customer Experience
* Ingredient Optimisation
* Pricing and Ratings
* Bonus DML Challenges (DML = Data Manipulation Language)

<Br>

# Question and Problems

**Note:**
* Most queries are written using MySQL.
* I will comment queries that are written on PostgreSQL.

## Data Cleaning

**1. Cleaning the `customer_orders` table**

* Dealing with NULL values

```sql
DROP TABLE IF EXISTS customer_orders_cleaned;
CREATE TABLE customer_orders_cleaned (
    SELECT
        order_id,
        customer_id,
        pizza_id,
        CASE
            WHEN exclusions LIKE 'null' OR exclusions LIKE '' THEN NULL
            ELSE exclusions
        END AS exclusions,
        CASE
            WHEN extras LIKE 'null' OR extras LIKE '' THEN NULL
            ELSE extras
        END AS extras,
        order_time
    FROM customer_orders
);

SELECT * FROM customer_orders_cleaned;
```

**Output**

| **order_id** | **customer_id** | **pizza_id** | **exclusions** | **extras** | **order_time**      |
|:------------:|:---------------:|:------------:|:--------------:|:----------:|:-------------------:|
| 1            | 101             | 1            | `NULL`         | `NULL`     | 2020-01-01 18:05:02 |
| 2            | 101             | 1            | `NULL`         | `NULL`     | 2020-01-01 19:00:52 |
| 3            | 102             | 1            | `NULL`         | `NULL`     | 2020-01-02 23:51:23 |
| 3            | 102             | 2            | `NULL`         | `NULL`     | 2020-01-02 23:51:23 |
| 4            | 103             | 1            | 4              | `NULL`     | 2020-01-04 13:23:46 |
| 4            | 103             | 1            | 4              | `NULL`     | 2020-01-04 13:23:46 |
| 4            | 103             | 2            | 4              | `NULL`     | 2020-01-04 13:23:46 |
| 5            | 104             | 1            | `NULL`         | 1          | 2020-01-08 21:00:29 |
| 6            | 101             | 2            | `NULL`         | `NULL`     | 2020-01-08 21:03:13 |
| 7            | 105             | 2            | `NULL`         | 1          | 2020-01-08 21:20:29 |
| 8            | 102             | 1            | `NULL`         | `NULL`     | 2020-01-09 23:54:33 |
| 9            | 103             | 1            | 4              | 1, 5       | 2020-01-10 11:22:59 |
| 10           | 104             | 1            | `NULL`         | `NULL`     | 2020-01-11 18:34:49 |
| 10           | 104             | 1            | 2, 6           | 1, 4       | 2020-01-11 18:34:49 |

<br>

**2. Cleaning the `runner_orders` table**

* Dealing with NULL values and incorrect data types

```sql
DROP TABLE IF EXISTS runner_orders_cleaned;
CREATE TABLE runner_orders_cleaned (
    SELECT
        order_id,
        runner_id,
        CASE
            WHEN pickup_time LIKE 'null' THEN NULL
            ELSE pickup_time
        END AS pickup_time,
        CASE
            WHEN distance LIKE 'null' THEN NULL
            WHEN distance LIKE '%km' 
                THEN TRIM('km' FROM distance)
            ELSE distance
        END AS distance,
        CASE
            WHEN duration LIKE 'null' THEN NULL
            WHEN duration LIKE '%min%' THEN TRIM('minutes' FROM TRIM('mins' FROM TRIM('minute' FROM duration)))
            ELSE duration
        END AS duration,
        CASE
            WHEN cancellation LIKE 'null' OR cancellation LIKE '' THEN NULL
            ELSE cancellation
        END AS cancellation
    FROM runner_orders
);

ALTER TABLE runner_orders_cleaned
MODIFY COLUMN distance FLOAT;

ALTER TABLE runner_orders_cleaned
MODIFY COLUMN duration INT;

ALTER TABLE runner_orders_cleaned
MODIFY COLUMN pickup_time TIMESTAMP;

DESCRIBE runner_orders_cleaned;

SELECT * FROM runner_orders_cleaned;
```

**Output**

`DESCRIBE TABLE`

| **Field**    | **Type**    | **Null** | **Key** | **Default** | **Extra** |
|:------------:|:-----------:|:--------:|:-------:|:-----------:|:---------:|
| order_id     | int         | YES      |         | `NULL`      |           |
| runner_id    | int         | YES      |         | `NULL`      |           |
| pickup_time  | timestamp   | YES      |         | `NULL`      |           |
| distance     | float       | YES      |         | `NULL`      |           |
| duration     | int         | YES      |         | `NULL`      |           |
| cancellation | varchar(23) | YES      |         | `NULL`      |           |
<br>

`runner_orders_cleaned`

| **order_id** | **runner_id** | **pickup_time**     | **distance** | **duration** | **cancellation**        |
|:------------:|:-------------:|:-------------------:|:------------:|:------------:|:-----------------------:|
| 1            | 1             | 2020-01-01 18:15:34 | 20           | 32           | `NULL`                  |
| 2            | 1             | 2020-01-01 19:10:54 | 20           | 27           | `NULL`                  |
| 3            | 1             | 2020-01-03 00:12:37 | 13.4         | 20           | `NULL`                  |
| 4            | 2             | 2020-01-04 13:53:03 | 23.4         | 40           | `NULL`                  |
| 5            | 3             | 2020-01-08 21:10:57 | 10           | 15           | `NULL`                  |
| 6            | 3             | `NULL`              | `NULL`       | `NULL`       | Restaurant Cancellation |
| 7            | 2             | 2020-01-08 21:30:45 | 25           | 25           | `NULL`                  |
| 8            | 2             | 2020-01-10 00:15:02 | 23.4         | 15           | `NULL`                  |
| 9            | 2             | `NULL`              | `NULL`       | `NULL`       | Customer Cancellation   |
| 10           | 1             | 2020-01-11 18:50:20 | 10           | 10           | `NULL`                  |
<br>

## A. Pizza Metrics

**1. How many pizzas were ordered?**

```sql
SELECT
    COUNT(*) AS total_orders
FROM customer_orders_cleaned;
```

**Answer**

| **total_orders** |
|:----------------:|
|14                |

<br>

**2. How many unique customer orders were made?**

```sql
SELECT
    COUNT(DISTINCT(order_id)) AS total_unique_orders
FROM customer_orders_cleaned;
```

**Answer**

| **total_unique_orders** |
|:-----------------------:|
| 10                      |

<br>

**3. How many successful orders were delivered by each runner?**

```sql
SELECT
    runner_id,
    COUNT(*) AS successful_order
FROM runner_orders_cleaned
WHERE
    cancellation IS NULL
GROUP BY
    runner_id;
```

**Answer**

| **runner_id** | **successful_order** |
|:-------------:|:--------------------:|
| 1             | 4                    |
| 2             | 3                    |
| 3             | 1                    |

<br>

**4. How many of each type of pizza was delivered?**

```sql
SELECT
    p.pizza_name,
    COUNT(*) AS pizza_delivered
FROM runner_orders_cleaned AS ro
JOIN customer_orders_cleaned AS co
    ON co.order_id = ro.order_id
JOIN pizza_names AS p
    ON p.pizza_id = co.pizza_id
WHERE
    ro.cancellation IS NULL
GROUP BY
    p.pizza_name;
```

**Answer**

| **pizza_name** | **pizza_delivered** |
|:--------------:|:-------------------:|
| Meatlovers     | 9                   |
| Vegetarian     | 3                   |

<br>

**5. How many Vegetarian and Meatlovers were ordered by each customer?**

```sql
SELECT
    customer_id,
    SUM(pizza_id = 1) AS meat_lovers,
    SUM(pizza_id = 2) AS vegetarian
FROM customer_orders_cleaned
GROUP BY
    customer_id;
```

**Answer**

| **customer_id** | **meat_lovers** | **vegetarian** |
|:---------------:|:---------------:|:--------------:|
| 101             | 2               | 1              |
| 102             | 2               | 1              |
| 103             | 3               | 1              |
| 104             | 3               | 0              |
| 105             | 0               | 1              |

<br>

**6. What was the maximum number of pizzas delivered in a single order?**

```sql
SELECT
    co.order_id,
    COUNT(co.pizza_id) AS pizza_delivered
FROM runner_orders_cleaned AS ro
JOIN customer_orders_cleaned AS co
    ON co.order_id = ro.order_id
WHERE
    ro.cancellation IS NULL
GROUP BY
    co.order_id
ORDER BY
    pizza_delivered DESC
LIMIT 1;
```

**Answer**

| **order_id** | **pizza_delivered** |
|:------------:|:-------------------:|
| 4            | 3                   |

<br>

**7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?**

```sql
SELECT
    customer_id,
    SUM(exclusions IS NOT NULL OR extras IS NOT NULL) AS has_change,
    SUM(exclusions IS NULL AND extras IS NULL) AS no_change
FROM customer_orders_cleaned
GROUP BY
    customer_id;
```

**Answer**

| **customer_id** | **has_change** | **no_change** |
|:---------------:|:--------------:|:-------------:|
| 101             | 0              | 3             |
| 102             | 0              | 3             |
| 103             | 4              | 0             |
| 104             | 2              | 1             |
| 105             | 1              | 0             |

<br>

**8. How many pizzas were delivered that had both exclusions and extras?**

```sql
SELECT
    COUNT(*) AS pizza_delivered
FROM runner_orders_cleaned AS ro
JOIN customer_orders_cleaned AS co
    ON co.order_id = ro.order_id
WHERE
    ro.cancellation IS NULL
    AND (co.exclusions IS NOT NULL AND co.extras IS NOT NULL);
```

**Answer**

| **pizza_delivered** |
|:-------------------:|
| 1                   |

<br>

**9. What was the total volume of pizzas ordered for each hour of the day?**

```sql
SELECT 
    HOUR(order_time) AS hour_of_day,
    COUNT(*) AS total_orders
FROM customer_orders_cleaned
GROUP BY
    HOUR(order_time)
ORDER BY
    hour_of_day;
```

**Answer**

| **hour_of_day** | **total_orders** |
|:---------------:|:----------------:|
| 11              | 1                |
| 13              | 3                |
| 18              | 3                |
| 19              | 1                |
| 21              | 3                |
| 23              | 3                |

<br>

**10. What was the volume of orders for each day of the week?**

```sql
SELECT
    DAYNAME(order_time) AS day_of_week,
    COUNT(*) AS total_orders
FROM customer_orders_cleaned
GROUP BY
    DAYNAME(order_time)
ORDER BY
    total_orders DESC;
```

**Answer**

| **day_of_week** | **total_orders** |
|:---------------:|:----------------:|
| Wednesday       | 5                |
| Saturday        | 5                |
| Thursday        | 3                |
| Friday          | 1                |

<br>














# Key Takeaways

From the SQL case study, I reinforced my understanding about:

1. Common Table Expressions (CTEs)
2. Group By Aggregates
3. Window Functions for Ranking
4. Table Joins

I also learned new SQL functions such as `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`, and `DATE_ADD()`.