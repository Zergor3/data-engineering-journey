-- Exploración de fuentes y validaciones del warehouse.
-- Los controles críticos fallan explícitamente si la carga no conserva el grano o las ventas.

DO $$
DECLARE
    source_orders bigint;
    unique_orders bigint;
    source_items bigint;
    unique_item_keys bigint;
    fact_items bigint;
    source_price numeric;
    fact_price numeric;
    source_payments bigint;
    fact_payments bigint;
BEGIN
    SELECT COUNT(*), COUNT(DISTINCT order_id)
    INTO source_orders, unique_orders
    FROM staging.olist_orders;

    IF source_orders <> unique_orders THEN
        RAISE EXCEPTION 'Validacion fallo: order_id no es unico (% filas, % claves)',
            source_orders, unique_orders;
    END IF;

    SELECT COUNT(*), COUNT(DISTINCT (order_id, order_item_id))
    INTO source_items, unique_item_keys
    FROM staging.olist_order_items;

    IF source_items <> unique_item_keys THEN
        RAISE EXCEPTION 'Validacion fallo: (order_id, order_item_id) no es unico (% filas, % claves)',
            source_items, unique_item_keys;
    END IF;

    SELECT COUNT(*), COALESCE(SUM(NULLIF(price, '')::numeric), 0)
    INTO source_items, source_price
    FROM staging.olist_order_items;

    SELECT COUNT(*), COALESCE(SUM(price), 0)
    INTO fact_items, fact_price
    FROM dw.fact_order_items;

    IF source_items <> fact_items OR source_price <> fact_price THEN
        RAISE EXCEPTION
            'Validacion fallo: staging (% filas, % price) != fact (% filas, % price)',
            source_items, source_price, fact_items, fact_price;
    END IF;

    SELECT COUNT(*) INTO source_payments FROM staging.olist_order_payments;
    SELECT COUNT(*) INTO fact_payments FROM dw.fact_payments;

    IF source_payments <> fact_payments THEN
        RAISE EXCEPTION 'Validacion fallo: staging payments (%) != fact_payments (%)',
            source_payments, fact_payments;
    END IF;

    RAISE NOTICE 'Validaciones criticas correctas: grano y reconciliacion de ventas preservados.';
END;
$$;

-- 1. order_id debe ser único en olist_orders.
SELECT
    COUNT(*) AS filas_totales,
    COUNT(DISTINCT order_id) AS order_id_distintos,
    COUNT(*) = COUNT(DISTINCT order_id) AS order_id_es_unico
FROM staging.olist_orders;

-- 2. Grano natural de order_items.
SELECT
    COUNT(*) AS filas_totales,
    COUNT(DISTINCT (order_id, order_item_id)) AS claves_distintas,
    COUNT(*) = COUNT(DISTINCT (order_id, order_item_id)) AS clave_es_unica
FROM staging.olist_order_items;

-- 3. Conteo de personas con ubicaciones de entrega distintas.
-- El detalle se conserva en sql/exploration.sql.
SELECT COUNT(*) AS clientes_con_ubicacion_multiple
FROM (
    SELECT customer_unique_id
    FROM staging.olist_customers
    GROUP BY customer_unique_id
    HAVING COUNT(DISTINCT customer_city) > 1
        OR COUNT(DISTINCT customer_state) > 1
) AS clientes;

-- 4. Nulos de productos y categorías sin traducción.
SELECT
    COUNT(*) FILTER (WHERE p.product_category_name IS NULL) AS sin_categoria,
    COUNT(*) FILTER (WHERE p.product_weight_g IS NULL) AS sin_peso,
    COUNT(*) FILTER (
        WHERE t.product_category_name IS NULL
          AND p.product_category_name IS NOT NULL
    ) AS sin_traduccion
FROM staging.olist_products p
LEFT JOIN staging.olist_product_category_name_translation t
    USING (product_category_name);

-- 5. Órdenes con más de un pago: evidencia de por qué fact_payments va separada.
SELECT COUNT(*) AS pedidos_con_mas_de_un_pago
FROM (
    SELECT order_id
    FROM staging.olist_order_payments
    GROUP BY order_id
    HAVING COUNT(*) > 1
) pagos_multiples;

-- 6. Reconciliación del grano de la fact principal.
SELECT
    (SELECT COUNT(*) FROM staging.olist_order_items) AS filas_staging,
    (SELECT COUNT(*) FROM dw.fact_order_items) AS filas_fact,
    (SELECT COUNT(*)
     FROM (
        SELECT order_id, order_item_id
        FROM dw.fact_order_items
        GROUP BY order_id, order_item_id
        HAVING COUNT(*) > 1
     ) duplicados) AS claves_duplicadas_en_fact;

-- 7. Reconciliación del grano de pagos.
SELECT
    (SELECT COUNT(*) FROM staging.olist_order_payments) AS filas_staging,
    (SELECT COUNT(*) FROM dw.fact_payments) AS filas_fact_payments,
    (SELECT COUNT(*)
     FROM (
        SELECT order_id, payment_sequential
        FROM dw.fact_payments
        GROUP BY order_id, payment_sequential
        HAVING COUNT(*) > 1
     ) duplicados) AS claves_duplicadas_en_fact_payments;
