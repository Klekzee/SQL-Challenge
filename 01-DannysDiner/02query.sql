-- 1. What is the total amount each customer spent at the restaurant?

SELECT 
	s.customer_id, 
    SUM(m.price) AS total_spent
FROM sales AS s
LEFT JOIN menu AS m
	ON m.product_id = s.product_id
GROUP BY s.customer_id;


-- 2. How many days has each customer visited the restaurant?

SELECT 
	COUNT(DISTINCT(order_date)) AS days_visited
FROM sales
GROUP BY customer_id;


-- 3. What was the first item from the menu purchased by each customer?

WITH CTE_first_purchase AS (
	SELECT 
		s.customer_id,
        s.order_date,
        m.product_name,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS ranking
	FROM sales AS s
    JOIN menu AS m
		ON m.product_id = s.product_id
)

SELECT 
	customer_id,
    product_name
FROM CTE_first_purchase
WHERE
	ranking = 1;


-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT
	m.product_name,
	COUNT(m.product_id) AS total_purchased
FROM menu AS m
JOIN sales AS s
	ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY total_purchased DESC
LIMIT 1;


-- 5. Which item was the most popular for each customer?

WITH CTE_most_popular_item AS (
	SELECT
		s.customer_id,
        m.product_name,
        COUNT(m.product_id) AS total_purchased,
        RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(m.product_id) DESC) AS ranking
	FROM sales AS s
    JOIN menu AS m
		ON m.product_id = s.product_id
	GROUP BY s.customer_id, m.product_name
)

SELECT
	customer_id,
    product_name,
    total_purchased
FROM CTE_most_popular_item
WHERE
	ranking = 1;


-- 6. Which item was purchased first by the customer after they became a member?

WITH CTE_first_purchace_members AS (
	SELECT
		mem.customer_id,
        mem.join_date,
        s.order_date,
        menu.product_name,
        RANK() OVER (PARTITION BY mem.customer_id ORDER BY s.order_date) AS ranking
	FROM members AS mem
    LEFT JOIN sales AS s
		ON s.customer_id = mem.customer_id
	LEFT JOIN menu
		ON menu.product_id = s.product_id
	WHERE
		s.order_date >= mem.join_date
)

SELECT
	customer_id,
    join_date,
    order_date,
    product_name
FROM CTE_first_purchace_members
WHERE
	ranking = 1;


-- 7. Which item was purchased just before the customer became a member?

WITH CTE_first_purchace_members AS (
	SELECT
		mem.customer_id,
        mem.join_date,
        s.order_date,
        menu.product_name,
        RANK() OVER (PARTITION BY mem.customer_id ORDER BY s.order_date DESC) AS ranking
	FROM members AS mem
    LEFT JOIN sales AS s
		ON s.customer_id = mem.customer_id
	LEFT JOIN menu
		ON menu.product_id = s.product_id
	WHERE
		s.order_date < mem.join_date
)

SELECT
	customer_id,
    join_date,
    order_date,
    product_name
FROM CTE_first_purchace_members
WHERE
	ranking = 1;


-- 8. What is the total items and amount spent for each member before they became a member?

WITH CTE_items_purchased_by_each_customer AS (
	SELECT
		members.customer_id,
		members.join_date,
		sales.order_date,
		sales.product_id,
		menu.product_name,
		menu.price
	FROM members
	JOIN sales
		ON sales.customer_id = members.customer_id
	JOIN menu
		ON menu.product_id = sales.product_id
	WHERE
		sales.order_date < members.join_date
)

SELECT
	customer_id,
	COUNT(*) AS total_items,
	SUM(price) AS total_amount
FROM CTE_items_purchased_by_each_customer
GROUP BY customer_id;

-- 8. Alternate Soln.

SELECT
	members.customer_id,
	COUNT(*) AS total_items,
	SUM(menu.price) AS total_amount
FROM members
JOIN sales
	ON sales.customer_id = members.customer_id
JOIN menu
	ON menu.product_id = sales.product_id
WHERE
	sales.order_date < members.join_date
GROUP BY customer_id;


-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?