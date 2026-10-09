{% macro date_key(column) %}
    to_char(({{ column }})::timestamp, 'YYYYMMDD')::int
{% endmacro %}