WITH products AS (
    SELECT * FROM {{ source('staging', 'olist_products') }}
),

translation AS (
    SELECT * FROM {{ source('staging', 'olist_product_category_name_translation') }}
)

SELECT
    ROW_NUMBER() OVER (ORDER BY p.product_id)::int AS product_key,
    p.product_id,
    COALESCE(p.product_category_name, 'unknown') AS product_category_name,
    COALESCE(
        t.product_category_name_english,
        CASE p.product_category_name
            WHEN 'pc_gamer' THEN 'pc_gamer'
            WHEN 'portateis_cozinha_e_preparadores_de_alimentos' THEN 'portable_kitchen_food_preparers'
        END,
        'unknown'
    ) AS product_category_name_english,
    p.product_weight_g::numeric::int AS product_weight_g
FROM products p
LEFT JOIN translation t
    ON t.product_category_name = p.product_category_name