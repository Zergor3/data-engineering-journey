-- Consultas exploratorias: producen detalle para inspeccion manual.
-- No forman parte de las validaciones automaticas de pasa/falla.

-- Personas que aparecen con mas de una ciudad o estado de entrega.
SELECT
    customer_unique_id,
    COUNT(DISTINCT customer_city) AS ciudades_distintas,
    COUNT(DISTINCT customer_state) AS estados_distintos
FROM staging.olist_customers
GROUP BY customer_unique_id
HAVING COUNT(DISTINCT customer_city) > 1
    OR COUNT(DISTINCT customer_state) > 1
ORDER BY estados_distintos DESC, ciudades_distintas DESC;
