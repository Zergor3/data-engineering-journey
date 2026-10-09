SELECT
    p.order_id,
    p.payment_sequential::int                      AS payment_sequential,
    dc.customer_key,
    {{ date_key('o.order_purchase_timestamp') }}   AS purchase_date_key,
    p.payment_type,
    p.payment_installments::int                    AS payment_installments,
    p.payment_value::numeric(10,2)                 AS payment_value
FROM {{ source('staging', 'olist_order_payments') }} p
JOIN {{ source('staging', 'olist_orders') }} o
    ON o.order_id = p.order_id
JOIN {{ source('staging', 'olist_customers') }} c
    ON c.customer_id = o.customer_id
JOIN {{ ref('dim_customer') }} dc
    ON dc.customer_unique_id = c.customer_unique_id