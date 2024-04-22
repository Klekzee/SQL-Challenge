-- Data Cleaning

SHOW TABLES;

-----------------------------------------------------------------------------------------
-- Cleaning customer_orders Table

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



-----------------------------------------------------------------------------------------
-- Cleaning runner_orders Table

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



-----------------------------------------------------------------------------------------
-- A. Pizza Metrics

-----------------------------------------------------------------------------------------
-- 1. How many pizzas were ordered?

SELECT
    COUNT(*) AS total_orders
FROM customer_orders_cleaned;



-----------------------------------------------------------------------------------------
-- 2. How many unique customer orders were made?

SELECT
    COUNT(DISTINCT(order_id)) AS total_unique_orders
FROM customer_orders_cleaned;



-----------------------------------------------------------------------------------------
-- 3. How many successful orders were delivered by each runner?

SELECT
    runner_id,
    COUNT(*) AS successful_order
FROM runner_orders_cleaned
WHERE
    cancellation IS NULL
GROUP BY
    runner_id;



-----------------------------------------------------------------------------------------
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



-----------------------------------------------------------------------------------------
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



-----------------------------------------------------------------------------------------
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



-----------------------------------------------------------------------------------------
-- 10. What was the volume of orders for each day of the week?

SELECT
    DAYNAME(order_time) AS day_of_week,
    COUNT(*) AS total_orders
FROM customer_orders_cleaned
GROUP BY
    DAYNAME(order_time)
ORDER BY
    total_orders DESC;