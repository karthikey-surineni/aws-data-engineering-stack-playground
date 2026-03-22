{{ config(
    materialized='table',
    table_type='iceberg',
    format='parquet'
) }}

WITH raw_data AS (
    SELECT *
    FROM {{ source('raw', 'raw_trades') }}
    WHERE year = cast(year(current_timestamp) as varchar)
      AND month = lpad(cast(month(current_timestamp) as varchar), 2, '0')
      AND day = lpad(cast(day(current_timestamp) as varchar), 2, '0')
)

SELECT
    s AS symbol,
    CAST(p AS DOUBLE) AS price_usd,
    CAST(q AS DOUBLE) AS quantity,
    t AS trade_id,
    from_unixtime(e_time / 1000) AS event_timestamp,
    m AS is_buyer_maker,
    year,
    month,
    day,
    hour
FROM raw_data
WHERE s IS NOT NULL
