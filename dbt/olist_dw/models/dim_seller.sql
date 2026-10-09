SELECT
    ROW_NUMBER() OVER (ORDER BY seller_id)::int AS seller_key,
    seller_id,
    seller_city,
    seller_state
FROM {{ source('staging', 'olist_sellers') }}