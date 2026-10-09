-- Carga repetible desde staging hacia dw.
-- Requiere que src/load_olist.py haya cargado todos los CSV de Olist.

TRUNCATE TABLE
    dw.dim_date,
    dw.fact_payments,
    dw.fact_order_items,
    dw.dim_customer,
    dw.dim_product,
    dw.dim_seller
RESTART IDENTITY CASCADE;

INSERT INTO dw.dim_date (
    date_key, full_date, year, quarter, month, day,
    week_of_year, day_of_week, day_name, is_weekend
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::integer,
    d::date,
    EXTRACT(year FROM d)::integer,
    EXTRACT(quarter FROM d)::integer,
    EXTRACT(month FROM d)::integer,
    EXTRACT(day FROM d)::integer,
    EXTRACT(week FROM d)::integer,
    EXTRACT(isodow FROM d)::integer,
    TRIM(TO_CHAR(d, 'Day')),
    EXTRACT(isodow FROM d) IN (6, 7)
FROM GENERATE_SERIES(
    DATE '2016-01-01', DATE '2019-12-31', INTERVAL '1 day'
) AS d
ON CONFLICT (date_key) DO NOTHING;

-- SCD tipo 1: conserva la ciudad/estado del pedido más reciente por persona.
INSERT INTO dw.dim_customer (
    customer_unique_id, customer_city, customer_state
)
SELECT DISTINCT ON (c.customer_unique_id)
    c.customer_unique_id,
    c.customer_city,
    c.customer_state
FROM staging.olist_customers c
JOIN staging.olist_orders o
    USING (customer_id)
ORDER BY
    c.customer_unique_id,
    NULLIF(o.order_purchase_timestamp, '')::timestamp DESC NULLS LAST,
    c.customer_id;

INSERT INTO dw.dim_product (
    product_id,
    product_category_name,
    product_category_name_english,
    product_weight_g
)
SELECT
    p.product_id,
    COALESCE(NULLIF(p.product_category_name, ''), 'unknown'),
    COALESCE(
        NULLIF(t.product_category_name_english, ''),
        CASE p.product_category_name
            WHEN 'pc_gamer' THEN 'pc_gamer'
            WHEN 'portateis_cozinha_e_preparadores_de_alimentos'
                THEN 'portable_kitchen_food_preparers'
        END,
        'unknown'
    ),
    NULLIF(p.product_weight_g, '')::numeric::integer
FROM staging.olist_products p
LEFT JOIN staging.olist_product_category_name_translation t
    USING (product_category_name);

INSERT INTO dw.dim_seller (seller_id, seller_city, seller_state)
SELECT seller_id, seller_city, seller_state
FROM staging.olist_sellers;

INSERT INTO dw.fact_order_items (
    order_id, order_item_id, customer_key, product_key, seller_key,
    purchase_date_key, approved_date_key, shipped_date_key,
    delivered_date_key, estimated_delivery_date_key,
    order_status, price, freight_value
)
SELECT
    i.order_id,
    i.order_item_id::integer,
    dc.customer_key,
    dp.product_key,
    ds.seller_key,
    dw.date_key(o.order_purchase_timestamp),
    dw.date_key(o.order_approved_at),
    dw.date_key(o.order_delivered_carrier_date),
    dw.date_key(o.order_delivered_customer_date),
    dw.date_key(o.order_estimated_delivery_date),
    o.order_status,
    NULLIF(i.price, '')::numeric(10, 2),
    NULLIF(i.freight_value, '')::numeric(10, 2)
FROM staging.olist_order_items i
JOIN staging.olist_orders o
    USING (order_id)
JOIN staging.olist_customers c
    ON c.customer_id = o.customer_id
JOIN dw.dim_customer dc
    ON dc.customer_unique_id = c.customer_unique_id
JOIN dw.dim_product dp
    ON dp.product_id = i.product_id
JOIN dw.dim_seller ds
    ON ds.seller_id = i.seller_id;

INSERT INTO dw.fact_payments (
    order_id, payment_sequential, customer_key, purchase_date_key,
    payment_type, payment_installments, payment_value
)
SELECT
    p.order_id,
    p.payment_sequential::integer,
    dc.customer_key,
    dw.date_key(o.order_purchase_timestamp),
    p.payment_type,
    NULLIF(p.payment_installments, '')::integer,
    NULLIF(p.payment_value, '')::numeric(10, 2)
FROM staging.olist_order_payments p
JOIN staging.olist_orders o
    USING (order_id)
JOIN staging.olist_customers c
    ON c.customer_id = o.customer_id
JOIN dw.dim_customer dc
    ON dc.customer_unique_id = c.customer_unique_id;

ANALYZE dw.fact_order_items;
ANALYZE dw.fact_payments;
