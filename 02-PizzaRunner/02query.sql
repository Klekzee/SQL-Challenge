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

SELECT
    co.customer_id,
    ROUND(AVG(ro.distance), 1) AS average_distance
FROM runner_orders_cleaned AS ro
JOIN customer_orders_cleaned AS co
    ON co.order_id = ro.order_id
WHERE
    ro.cancellation IS NULL
GROUP BY
    co.customer_id;



----------------------------------------------------------------------------------------------------------
-- 5. What was the difference between the longest and shortest delivery times for all orders?

SELECT
    MAX(duration) AS longest_delivery_time,
    MIN(duration) AS shortest_delivery_time,
    (MAX(duration) - MIN(duration)) AS time_diff
FROM runner_orders_cleaned
WHERE
    cancellation IS NULL;



----------------------------------------------------------------------------------------------------------
-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?

-- Note: Speed unit will be km/hr

SELECT
    order_id,
    runner_id,
    ROUND(distance / (duration / 60), 2) AS average_speed
FROM runner_orders_cleaned
WHERE
    cancellation IS NULL



----------------------------------------------------------------------------------------------------------
-- 7. What is the successful delivery percentage for each runner?

WITH CTE_successful_deliveries AS (
    SELECT
        runner_id,
        COUNT(*) AS successful_orders
    FROM runner_orders_cleaned
    WHERE
        cancellation IS NULL
    GROUP BY
        runner_id
),

CTE_total_deliveries AS (
    SELECT
        runner_id,
        COUNT(*) AS total_orders
    FROM runner_orders_cleaned
    GROUP BY
        runner_id
)

SELECT
    sd.runner_id,
    ROUND((successful_orders / total_orders) * 100, 1) AS percentage
FROM CTE_successful_deliveries AS sd
JOIN CTE_total_deliveries AS td
    ON td.runner_id = sd.runner_id;





----------------------------------------------------------------------------------------------------------

-- C. Ingredient Optimisation

----------------------------------------------------------------------------------------------------------
-- Normalizing the pizza_recipes table

SELECT * FROM pizza_recipes;

DROP TABLE IF EXISTS pizza_recipes_normalized;
CREATE TABLE pizza_recipes_normalized (
    pizza_id INT,
    toppings INT
);

INSERT INTO pizza_recipes_normalized (pizza_id, toppings)
VALUES
    (1, 1),
    (1, 2),
    (1, 3),
    (1, 4),
    (1, 5),
    (1, 6),
    (1, 8),
    (1, 10),
    (2, 4),
    (2, 6),
    (2, 7),
    (2, 9),
    (2, 11),
    (2, 12);

SELECT * FROM pizza_recipes_normalized;



----------------------------------------------------------------------------------------------------------
-- 1. What are the standard ingredients for each pizza?

WITH CTE_standard_ingd AS (
    SELECT
        pn.pizza_id,
        pn.pizza_name,
        pr.toppings,
        pt.topping_name
    FROM pizza_names AS pn
    JOIN pizza_recipes_normalized AS pr
        ON pr.pizza_id = pn.pizza_id
    JOIN pizza_toppings AS pt
        ON pt.topping_id = pr.toppings
    ORDER BY
        pn.pizza_id
)

SELECT
    pizza_name,
    GROUP_CONCAT(topping_name SEPARATOR ', ') AS standard_ingredients
FROM CTE_standard_ingd
GROUP BY
    pizza_name;



----------------------------------------------------------------------------------------------------------
-- 2. What was the most commonly added extra?

WITH CTE_common_extra AS (
    SELECT
        SUBSTR(extras, 1, 1) AS extra_id
    FROM customer_orders_cleaned
    WHERE
        extras IS NOT NULL
    UNION ALL
    SELECT
        SUBSTRING_INDEX(extras, ",", -1) AS extra_id
    FROM customer_orders_cleaned
    WHERE
        LENGTH(extras) > 1
)

SELECT
    ce.extra_id AS topping_id,
    COUNT(ce.extra_id) AS occurence,
    pt.topping_name
FROM CTE_common_extra AS ce
JOIN pizza_toppings AS pt
    ON pt.topping_id = ce.extra_id
GROUP BY
    ce.extra_id, pt.topping_name
ORDER BY
    occurence DESC
LIMIT 1;



----------------------------------------------------------------------------------------------------------
-- 3. What was the most common exclusion?

WITH CTE_common_exclusion AS (
    SELECT
        SUBSTR(exclusions, 1, 1) AS exclusion_id
    FROM customer_orders_cleaned
    WHERE
        exclusions IS NOT NULL
    UNION ALL
    SELECT
        SUBSTRING_INDEX(exclusions, ",", -1) AS exclusion_id
    FROM customer_orders_cleaned
    WHERE
        LENGTH(exclusions) > 1
)

SELECT
    ce.exclusion_id AS topping_id,
    COUNT(ce.exclusion_id) AS occurence,
    pt.topping_name
FROM CTE_common_exclusion AS ce
JOIN pizza_toppings AS pt
    ON pt.topping_id = ce.exclusion_id
GROUP BY
    ce.exclusion_id, pt.topping_name
ORDER BY
    occurence DESC
LIMIT 1;



----------------------------------------------------------------------------------------------------------
-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
--      * Meat Lovers
--      * Meat Lovers - Exclude Beef
--      * Meat Lovers - Extra Bacon
--      * Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

-- Comment:
-- This is a total mess, but it automatically returns the topping name whatever exclusion_id or extras_id are inputed.
-- It can be solve without using CTE but it will become even messier.
-- I am also assuming that you can only have max 2 exclusions and extras.
-- Do let me know if there is a better way to solve this.

WITH CTE_order_item AS (
    SELECT
        *,
        CASE
            WHEN pizza_id = 1 THEN 'Meat Lovers'
            ELSE 'Veggie Lovers'
        END AS order_item_name,
        CASE
            WHEN LENGTH(exclusions) > 1
            THEN CONCAT('Exclude ', CONCAT_WS(', ', (
                SELECT topping_name
                FROM pizza_toppings
                WHERE topping_id = SUBSTR(exclusions, 1, 1)), (
                    SELECT topping_name
                    FROM pizza_toppings
                    WHERE topping_id = SUBSTR(exclusions, 4, 1))))
            ELSE CONCAT('Exclude ', (
                SELECT topping_name
                FROM pizza_toppings
                WHERE topping_id = SUBSTR(exclusions, 1, 1)))
        END AS order_item_exclusions,
        CASE
            WHEN LENGTH(extras) > 1
            THEN CONCAT('Extra ', CONCAT_WS(', ', (
                SELECT topping_name
                FROM pizza_toppings
                WHERE topping_id = SUBSTR(extras, 1, 1)), (
                    SELECT topping_name
                    FROM pizza_toppings
                    WHERE topping_id = SUBSTR(extras, 4, 1))))
            ELSE CONCAT('Extra ', (
                SELECT topping_name
                FROM pizza_toppings
                WHERE topping_id = SUBSTR(extras, 1, 1)))
        END AS order_item_extras
    FROM customer_orders_cleaned
)

SELECT
    order_id,
    customer_id,
    pizza_id,
    exclusions,
    extras,
    order_time,
    CONCAT_WS(' - ', order_item_name, order_item_exclusions, order_item_extras) AS order_item
FROM CTE_order_item;



----------------------------------------------------------------------------------------------------------
-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
--      * For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

-- Comment:
-- Super Difficult without a SPLIT_TO_TABLE function because MySQL doesn't support it.
-- On Hold for now

SELECT * FROM customer_orders_cleaned;
SELECT * FROM pizza_recipes_normalized;
SELECT * FROM pizza_toppings;

WITH CTE_base_pizza_ing AS (
    SELECT
        pizza_id,
        GROUP_CONCAT(topping_name SEPARATOR ', ') AS ingredient_list
    FROM pizza_recipes_normalized AS pr
    JOIN pizza_toppings AS pt
        ON pt.topping_id = pr.toppings
    GROUP BY
        pizza_id
),

CTE_order_item AS (
    SELECT
        *,
        CASE
            WHEN pizza_id = 1 THEN 'Meat Lovers'
            ELSE 'Veggie Lovers'
        END AS order_item_name,
        CASE
            WHEN LENGTH(exclusions) > 1
            THEN CONCAT_WS(', ', (
                SELECT topping_name
                FROM pizza_toppings
                WHERE topping_id = SUBSTR(exclusions, 1, 1)), (
                    SELECT topping_name
                    FROM pizza_toppings
                    WHERE topping_id = SUBSTR(exclusions, 4, 1)))
            ELSE (
                SELECT topping_name
                FROM pizza_toppings
                WHERE topping_id = exclusions)
        END AS order_item_exclusions,
        CASE
            WHEN LENGTH(extras) > 1
            THEN CONCAT_WS(', ', (
                SELECT topping_name
                FROM pizza_toppings
                WHERE topping_id = SUBSTR(extras, 1, 1)), (
                    SELECT topping_name
                    FROM pizza_toppings
                    WHERE topping_id = SUBSTR(extras, 4, 1)))
            ELSE (
                SELECT topping_name
                FROM pizza_toppings
                WHERE topping_id = SUBSTR(extras, 1, 1))
        END AS order_item_extras
    FROM customer_orders_cleaned
)

SELECT
    *
FROM CTE_order_item AS oi
JOIN CTE_base_pizza_ing AS pi
    ON pi.pizza_id = oi.pizza_id;

SELECT
    CASE
        WHEN LENGTH(exclusions) > 1
        THEN CONCAT(order_item_name, ': ', (
            REPLACE(pi.ingredient_list, SUBSTRING_INDEX(oi.order_item_exclusions, ', ', -1), '')
            AND REPLACE(pi.ingredient_list, SUBSTRING_INDEX(oi.order_item_exclusions, ', ', 1), '')))
    ELSE CONCAT(order_item_name, ': ', (
            REPLACE(pi.ingredient_list, order_item_exclusions, '')))
    END AS test
FROM CTE_order_item AS oi
JOIN CTE_base_pizza_ing AS pi
    ON pi.pizza_id = oi.pizza_id;



----------------------------------------------------------------------------------------------------------
-- 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

-- WORK IN PROGRESS





----------------------------------------------------------------------------------------------------------

-- D. Pricing and Ratings

----------------------------------------------------------------------------------------------------------
-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?

WITH CTE_total_revenue AS (
    SELECT
        CASE
            WHEN co.pizza_id = 1 THEN 12
            ELSE 10
        END AS gross
    FROM customer_orders_cleaned AS co
    JOIN runner_orders_cleaned AS ro
        ON ro.order_id = co.order_id
    WHERE
        ro.cancellation IS NULL
)

SELECT
    SUM(gross) AS total_revenue
FROM CTE_total_revenue;



----------------------------------------------------------------------------------------------------------
-- 2. What if there was an additional $1 charge for any pizza extras?
--      * Add cheese is $1 extra

WITH CTE_total_revenue AS (
    SELECT
        CASE
            WHEN co.pizza_id = 1 AND LENGTH(co.extras) > 1
                THEN 12 + 2
            WHEN co.pizza_id = 1 AND LENGTH(co.extras) = 1
                THEN 12 + 1
            WHEN co.pizza_id = 1 THEN 12
            WHEN co.pizza_id = 2 AND LENGTH(co.extras) > 1
                THEN 10 + 2
            WHEN co.pizza_id = 2 AND LENGTH(co.extras) = 1
                THEN 10 + 1
            WHEN co.pizza_id = 2 THEN 10
        END AS gross_with_extras
    FROM customer_orders_cleaned AS co
    JOIN runner_orders_cleaned AS ro
        ON ro.order_id = co.order_id
    WHERE
        ro.cancellation IS NULL
)

SELECT
    SUM(gross_with_extras) AS total_revenue
FROM CTE_total_revenue;



----------------------------------------------------------------------------------------------------------
-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset
--    - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.

-- Ratings Based on:
--      * Efficiency (Delivery is on time)
--      * Food Status (Delivery instructions were followed)
--      * Runners Service (Runners professionalism)

-- Bonus:
--      * Overall Rating (Average of the other ratings)

DROP TABLE IF EXISTS runner_orders_ratings;
CREATE TABLE runner_orders_ratings (
    order_id INT,
    runner_id INT,
    efficiency INT,
    food_status INT,
    service INT,
    PRIMARY KEY (order_id)
);

INSERT INTO runner_orders_ratings (order_id, runner_id, efficiency, food_status, service)
VALUES
    (1, 1, 4, 5, 4),
    (2, 1, 5, 5, 5),
    (3, 1, 4, 4, 5),
    (4, 2, 4, 5, 4),
    (5, 3, 3, 4, 3),
    (7, 2, 5, 3, 4),
    (8, 2, 3, 5, 4),
    (10, 1, 4, 4, 3);

SELECT * FROM runner_orders_ratings;

-- Getting the overall_rating per runner.
SELECT
    runner_id,
    ROUND((AVG(efficiency) + AVG(food_status) + AVG(service)) / 3, 1) AS overall_rating
FROM runner_orders_ratings
GROUP BY
    runner_id;



----------------------------------------------------------------------------------------------------------
-- 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?

--      * customer_id
--      * order_id
--      * runner_id
--      * rating
--      * order_time
--      * pickup_time
--      * Time between order and pickup
--      * Delivery duration
--      * Average speed
--      * Total number of pizzas

WITH CTE_customer_orders_normalized AS (
    SELECT
        order_id,
        customer_id,
        order_time,
        COUNT(pizza_id) AS total_pizza_ordered
    FROM customer_orders_cleaned
    GROUP BY
        order_id, customer_id, order_time
)

SELECT
    co.customer_id,
    ro.order_id,
    ro.runner_id,
    ROUND((rr.efficiency + rr.food_status + rr.service) / 3, 1) AS rating,
    co.order_time,
    ro.pickup_time,
    ROUND(TIMESTAMPDIFF(MINUTE, co.order_time, ro.pickup_time), 1) AS order_pickup_time_diff,
    ro.duration,
    ROUND(ro.distance / (ro.duration / 60), 2) AS average_speed_kph,
    co.total_pizza_ordered
FROM CTE_customer_orders_normalized AS co
JOIN runner_orders_cleaned AS ro
    ON ro.order_id = co.order_id
JOIN runner_orders_ratings AS rr
    ON rr.order_id = ro.order_id
WHERE
    ro.cancellation IS NULL;



----------------------------------------------------------------------------------------------------------
-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled 
--    - how much money does Pizza Runner have left over after these deliveries?

-- Compute the pay for each runner then sum it all up
-- Total revenue - Pay for all runner = Money Left

WITH CTE_total_revenue AS (
    SELECT
        runner_id,
        SUM(CASE
            WHEN co.pizza_id = 1 THEN 12
            ELSE 10
        END) AS gross
    FROM customer_orders_cleaned AS co
    JOIN runner_orders_cleaned AS ro
        ON ro.order_id = co.order_id
    WHERE
        ro.cancellation IS NULL
    GROUP BY runner_id
),

CTE_total_pay_for_runners AS (
    SELECT
        runner_id,
        SUM(ROUND(distance * 0.3, 2)) AS pay
    FROM runner_orders_cleaned
    WHERE
        cancellation IS NULL
    GROUP BY
        runner_id
)

SELECT
    SUM(gross) AS total_revenue,
    SUM(pay) AS total_pay,
    (SUM(gross) - SUM(pay)) AS money_left
FROM CTE_total_revenue AS tr
JOIN CTE_total_pay_for_runners AS tp
    ON tp.runner_id = tr.runner_id;





---