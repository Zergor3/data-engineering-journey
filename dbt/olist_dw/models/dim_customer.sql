WITH customers AS (
    SELECT * FROM {{ source('staging', 'olist_customers') }}
),

orders AS (
    SELECT customer_id, order_purchase_timestamp
    FROM {{ source('staging', 'olist_orders') }}
),

ranked AS (
    SELECT
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp::timestamp DESC, c.customer_id
        ) AS rn
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
)

SELECT
    ROW_NUMBER() OVER (ORDER BY customer_unique_id)::int AS customer_key,
    customer_unique_id,
    customer_city,
    customer_state
FROM ranked
WHERE rn = 1