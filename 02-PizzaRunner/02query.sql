-- Data Cleaning

SHOW TABLES;

----------------------------------------------------------------------------------------------------------
-- Cleaning customer_orders Table
-- Dealing with NULL values

DESCRIBE customer_orders;

SELECT * FROM customer_orders;

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



----------------------------------------------------------------------------------------------------------
-- Cleaning runner_orders Table
-- Dealing with NULL values and incorrect DATA TYPES

DESCRIBE runner_orders;
-- Noticed that pickup_time column is a VARCHAR(19) data type instead of a date
-- Same goes for distance and duration where they should be NUMERIC and INT

SELECT * FROM runner_orders;

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





----------------------------------------------------------------------------------------------------------

-- A. Pizza Metrics

----------------------------------------------------------------------------------------------------------
-- 1. How many pizzas were ordered?

SELECT
    COUNT(*) AS total_orders
FROM customer_orders_cleaned;



----------------------------------------------------------------------------------------------------------
-- 2. How many unique customer orders were made?

SELECT
    COUNT(DISTINCT(order_id)) AS total_unique_orders
FROM customer_orders_cleaned;



----------------------------------------------------------------------------------------------------------
-- 3. How many successful orders were delivered by each runner?

SELECT
    runner_id,
    COUNT(*) AS successful_order
FROM runner_orders_cleaned
WHERE
    cancellation IS NULL
GROUP BY
    runner_id;



----------------------------------------------------------------------------------------------------------
-- 4. How many of each type of pizza was delivered?

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



----------------------------------------------------------------------------------------------------------
-- 5. How many Vegetarian and Meatlovers were ordered by each customer?

SELECT
    customer_id,
    SUM(pizza_id = 1) AS meat_lovers,
    SUM(pizza_id = 2) AS vegetarian
    -- SUM instead of COUNT because when the condition pizza_id = 1 is true, it evaluates to 1.
    -- When the condition is false, it evaluates to 0.
FROM customer_orders_cleaned
GROUP BY
    customer_id;



----------------------------------------------------------------------------------------------------------
-- 6. What was the maximum number of pizzas delivered in a single order?

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



----------------------------------------------------------------------------------------------------------
-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

SELECT
    customer_id,
    SUM(exclusions IS NOT NULL OR extras IS NOT NULL) AS has_change,
    SUM(exclusions IS NULL AND extras IS NULL) AS no_change
    -- Same logic as #5
FROM customer_orders_cleaned
GROUP BY
    customer_id;



----------------------------------------------------------------------------------------------------------
-- 8. How many pizzas were delivered that had both exclusions and extras?

SELECT
    COUNT(*) AS pizza_delivered
FROM runner_orders_cleaned AS ro
JOIN customer_orders_cleaned AS co
    ON co.order_id = ro.order_id
WHERE
    ro.cancellation IS NULL
    AND (co.exclusions IS NOT NULL AND co.extras IS NOT NULL);

-- Validation
SELECT
    co.order_id,
    co.pizza_id,
    co.exclusions,
    co.extras
FROM runner_orders_cleaned AS ro
JOIN customer_orders_cleaned AS co
    ON co.order_id = ro.order_id
WHERE
    ro.cancellation IS NULL
    AND (co.exclusions IS NOT NULL AND co.extras IS NOT NULL);



----------------------------------------------------------------------------------------------------------
-- 9. What was the total volume of pizzas ordered for each hour of the day?

SELECT 
    HOUR(order_time) AS hour_of_day,
    COUNT(*) AS total_orders
FROM customer_orders_cleaned
GROUP BY
    HOUR(order_time)
ORDER BY
    hour_of_day;



----------------------------------------------------------------------------------------------------------
-- 10. What was the volume of orders for each day of the week?

SELECT
    DAYNAME(order_time) AS day_of_week,
    COUNT(*) AS total_orders
FROM customer_orders_cleaned
GROUP BY
    DAYNAME(order_time)
ORDER BY
    total_orders DESC;





----------------------------------------------------------------------------------------------------------

-- B. Runner and Customer Experience

----------------------------------------------------------------------------------------------------------
-- 1. How many runners signed up for each 1 week period? (i.e. week starts `2021-01-01`)

SELECT
    EXTRACT(WEEK FROM registration_date) AS week,
    COUNT(*) AS runners
FROM runners
GROUP BY
    EXTRACT(WEEK FROM registration_date);



----------------------------------------------------------------------------------------------------------
-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

SELECT
    ro.runner_id,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, co.order_time, ro.pickup_time)), 1) AS average_time
FROM runner_orders_cleaned AS ro
JOIN customer_orders_cleaned AS co
    ON co.order_id = ro.order_id
WHERE
    ro.cancellation IS NULL
GROUP BY
    ro.runner_id;



----------------------------------------------------------------------------------------------------------
-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

-- Create a CTE to get number of pizzas per order, then get the difference between order time and pickup time.
-- Group by order_id.
WITH CTE_pizzacount_time_relation AS (
    SELECT
        co.order_id,
        COUNT(co.pizza_id) AS number_of_pizza,
        TIMESTAMPDIFF(MINUTE, co.order_time, ro.pickup_time) AS time_diff
    FROM customer_orders_cleaned AS co
    JOIN runner_orders_cleaned AS ro
        ON ro.order_id = co.order_id
    WHERE
        ro.cancellation IS NULL
    GROUP BY
        co.order_id,
        TIMESTAMPDIFF(MINUTE, co.order_time, ro.pickup_time)
)

SELECT
    number_of_pizza,
    AVG(time_diff) AS average_time
FROM CTE_pizzacount_time_relation
GROUP BY
    number_of_pizza;

-- From observation, number of pizzas and average time to prepare have a positive correlation.
-- The more pizzas per order, the longer its preparation time.



----------------------------------------------------------------------------------------------------------
-- 4. What was the average distance travelled for each customer?