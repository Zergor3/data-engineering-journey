-- Falla si hay una categoría real sin traducción al inglés
SELECT product_id, product_category_name
FROM {{ ref('dim_product') }}
WHERE product_category_name <> 'unknown'
  AND product_category_name_english = 'unknown'