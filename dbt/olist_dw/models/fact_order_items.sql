SELECT
    i.order_id,
    i.order_item_id::int                                   AS order_item_id,
    dc.customer_key,
    dp.product_key,
    ds.seller_key,
    {{ date_key('o.order_purchase_timestamp') }}           AS purchase_date_key,
    {{ date_key('o.order_approved_at') }}                  AS approved_date_key,
    {{ date_key('o.order_delivered_carrier_date') }}       AS shipped_date_key,
    {{ date_key('o.order_delivered_customer_date') }}      AS delivered_date_key,
    {{ date_key('o.order_estimated_delivery_date') }}      AS estimated_delivery_date_key,
    o.order_status,
    i.price::numeric(10,2)                                 AS price,
    i.freight_value::numeric(10,2)                         AS freight_value
FROM {{ source('staging', 'olist_order_items') }} i
JOIN {{ source('staging', 'olist_orders') }} o
    ON o.order_id = i.order_id
JOIN {{ source('staging', 'olist_customers') }} c
    ON c.customer_id = o.customer_id
JOIN {{ ref('dim_customer') }} dc
    ON dc.customer_unique_id = c.customer_unique_id
JOIN {{ ref('dim_product') }} dp
    ON dp.product_id = i.product_id
JOIN {{ ref('dim_seller') }} ds
    ON ds.seller_id = i.seller_id