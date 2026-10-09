SELECT
    to_char(d, 'YYYYMMDD')::int           AS date_key,
    d::date                               AS full_date,
    EXTRACT(year FROM d)::int             AS year,
    EXTRACT(quarter FROM d)::int          AS quarter,
    EXTRACT(month FROM d)::int            AS month,
    EXTRACT(day FROM d)::int              AS day,
    EXTRACT(week FROM d)::int             AS week_of_year,
    EXTRACT(isodow FROM d)::int           AS day_of_week,
    trim(to_char(d, 'Day'))               AS day_name,
    EXTRACT(isodow FROM d) IN (6, 7)      AS is_weekend
FROM generate_series('2016-01-01'::date, '2019-12-31'::date, interval '1 day') AS d