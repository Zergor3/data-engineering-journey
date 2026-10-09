-- 1. Ventas mensuales y variación frente al mes anterior.
-- La serie de calendario hace explícito cualquier mes sin ventas.
WITH meses AS (
    SELECT DATE_TRUNC('month', full_date)::date AS mes
    FROM dw.dim_date
    WHERE full_date BETWEEN DATE '2017-01-01' AND DATE '2018-08-31'
    GROUP BY 1
),
ventas_mensuales AS (
    SELECT
        DATE_TRUNC('month', d.full_date)::date AS mes,
        SUM(f.price) AS ventas
    FROM dw.fact_order_items f
    JOIN dw.dim_date d
        ON d.date_key = f.purchase_date_key
    WHERE f.order_status NOT IN ('canceled', 'unavailable')
      AND d.full_date BETWEEN DATE '2017-01-01' AND DATE '2018-08-31'
    GROUP BY 1
),
serie_completa AS (
    SELECT m.mes, COALESCE(v.ventas, 0) AS ventas
    FROM meses m
    LEFT JOIN ventas_mensuales v
        ON v.mes = m.mes
),
con_mes_anterior AS (
    SELECT
        mes,
        ventas,
        LAG(ventas) OVER (ORDER BY mes) AS ventas_mes_anterior
    FROM serie_completa
)
SELECT
    mes,
    ROUND(ventas, 2) AS ventas,
    ROUND(ventas_mes_anterior, 2) AS ventas_mes_anterior,
    ROUND(ventas - ventas_mes_anterior, 2) AS variacion_absoluta,
    ROUND(
        100.0 * (ventas - ventas_mes_anterior)
        / NULLIF(ventas_mes_anterior, 0),
        2
    ) AS variacion_porcentual
FROM con_mes_anterior
ORDER BY mes;

-- 2. Top 5 categorías por ventas dentro de cada año.
-- Nota: 2016 (sep-dic) y 2018 (ene-ago) son años parciales, no comparables con 2017.
WITH ventas_por_categoria AS (
    SELECT
        d.year,
        p.product_category_name_english AS categoria,
        SUM(f.price) AS ventas
    FROM dw.fact_order_items f
    JOIN dw.dim_date d
        ON d.date_key = f.purchase_date_key
    JOIN dw.dim_product p
        ON p.product_key = f.product_key
    WHERE f.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY d.year, p.product_category_name_english
),
categorias_rankeadas AS (
    SELECT
        year,
        categoria,
        ventas,
        DENSE_RANK() OVER (
            PARTITION BY year
            ORDER BY ventas DESC
        ) AS posicion
    FROM ventas_por_categoria
)
SELECT
    year,
    categoria,
    ROUND(ventas, 2) AS ventas,
    posicion
FROM categorias_rankeadas
WHERE posicion <= 5
ORDER BY year, posicion, categoria;

-- 3. Porcentaje de pedidos entregados después de la fecha estimada.
-- Reduce primero a una fila por pedido para no contar ítems varias veces.
WITH fechas_por_pedido AS (
    SELECT
        order_id,
        MAX(delivered_date_key) AS delivered_date_key,
        MAX(estimated_delivery_date_key) AS estimated_delivery_date_key
    FROM dw.fact_order_items
    GROUP BY order_id
)
SELECT
    COUNT(*) AS pedidos_con_fechas,
    COUNT(*) FILTER (
        WHERE delivered_date_key > estimated_delivery_date_key
    ) AS pedidos_entregados_tarde,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delivered_date_key > estimated_delivery_date_key
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS porcentaje_entregados_tarde
FROM fechas_por_pedido
WHERE delivered_date_key IS NOT NULL
  AND estimated_delivery_date_key IS NOT NULL;
