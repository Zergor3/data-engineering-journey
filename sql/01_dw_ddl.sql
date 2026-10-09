-- Modelo dimensional para el dataset Olist.
-- Ejecutar antes de 02_dw_load.sql.

CREATE SCHEMA IF NOT EXISTS dw;

-- Convierte los timestamps ISO de staging en claves YYYYMMDD.
CREATE OR REPLACE FUNCTION dw.date_key(ts_text text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN NULLIF(BTRIM(ts_text), '') IS NULL THEN NULL
        ELSE TO_CHAR(ts_text::timestamp, 'YYYYMMDD')::integer
    END;
$$;

CREATE TABLE IF NOT EXISTS dw.dim_date (
    date_key     integer PRIMARY KEY,
    full_date    date NOT NULL UNIQUE,
    year         integer NOT NULL,
    quarter      integer NOT NULL,
    month        integer NOT NULL,
    day          integer NOT NULL,
    week_of_year integer NOT NULL,
    day_of_week  integer NOT NULL,
    day_name     text NOT NULL,
    is_weekend   boolean NOT NULL
);

CREATE TABLE IF NOT EXISTS dw.dim_customer (
    customer_key       serial PRIMARY KEY,
    customer_unique_id text NOT NULL UNIQUE,
    customer_city      text,
    customer_state     text
);

CREATE TABLE IF NOT EXISTS dw.dim_product (
    product_key                   serial PRIMARY KEY,
    product_id                    text NOT NULL UNIQUE,
    product_category_name         text,
    product_category_name_english text,
    product_weight_g              integer
);

CREATE TABLE IF NOT EXISTS dw.dim_seller (
    seller_key   serial PRIMARY KEY,
    seller_id    text NOT NULL UNIQUE,
    seller_city  text,
    seller_state text
);

CREATE TABLE IF NOT EXISTS dw.fact_order_items (
    order_id                    text NOT NULL,
    order_item_id               integer NOT NULL,
    customer_key                integer NOT NULL REFERENCES dw.dim_customer(customer_key),
    product_key                 integer NOT NULL REFERENCES dw.dim_product(product_key),
    seller_key                  integer NOT NULL REFERENCES dw.dim_seller(seller_key),
    purchase_date_key           integer REFERENCES dw.dim_date(date_key),
    approved_date_key           integer REFERENCES dw.dim_date(date_key),
    shipped_date_key            integer REFERENCES dw.dim_date(date_key),
    delivered_date_key          integer REFERENCES dw.dim_date(date_key),
    estimated_delivery_date_key integer REFERENCES dw.dim_date(date_key),
    order_status                text,
    price                       numeric(10, 2),
    freight_value               numeric(10, 2),
    PRIMARY KEY (order_id, order_item_id)
);

-- Fact separada: no se une a order_items para evitar multiplicar pagos por ítems.
CREATE TABLE IF NOT EXISTS dw.fact_payments (
    order_id          text NOT NULL,
    payment_sequential integer NOT NULL,
    customer_key      integer NOT NULL REFERENCES dw.dim_customer(customer_key),
    purchase_date_key integer REFERENCES dw.dim_date(date_key),
    payment_type      text,
    payment_installments integer,
    payment_value     numeric(10, 2),
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE INDEX IF NOT EXISTS idx_fact_order_items_purchase_date
    ON dw.fact_order_items (purchase_date_key);
CREATE INDEX IF NOT EXISTS idx_fact_order_items_product
    ON dw.fact_order_items (product_key);
CREATE INDEX IF NOT EXISTS idx_fact_payments_purchase_date
    ON dw.fact_payments (purchase_date_key);
