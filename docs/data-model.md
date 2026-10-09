# Referencia del modelo dimensional

## Granos

| Tabla | Grano | Clave natural |
|---|---|---|
| `dw.fact_order_items` | Un artículo dentro de un pedido | `(order_id, order_item_id)` |
| `dw.fact_payments` | Un pago aplicado a un pedido | `(order_id, payment_sequential)` |
| `dw.dim_customer` | Una persona Olist | `customer_unique_id` |
| `dw.dim_product` | Un producto | `product_id` |
| `dw.dim_seller` | Un vendedor | `seller_id` |
| `dw.dim_date` | Un día de calendario | `date_key` (`YYYYMMDD`) |

## Relaciones importantes

`fact_order_items` contiene cinco claves hacia `dim_date`: compra, aprobación, envío al transportista, entrega y fecha estimada. Es una dimensión role-playing.

`fact_payments` se mantiene separada de `fact_order_items`: un pedido puede tener varios ítems y varios pagos. Unir ambas facts por `order_id` multiplica filas y sobreestima importes.

El diagrama con colores se mantiene en el [README](../README.md#modelo-estrella), donde GitHub renderiza Mermaid de forma nativa.
