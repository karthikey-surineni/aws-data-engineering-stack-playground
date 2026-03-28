{{ config(
    materialized='incremental',
    table_type='iceberg',
    format='parquet',
    incremental_strategy='append',
    on_schema_change='append_new_columns',
    partitioned_by=['day(event_timestamp)']
) }}

SELECT
    trade_id,
    symbol,
    price_usd,
    quantity,
    price_usd * quantity AS trade_value_usd,
    event_timestamp,
    is_buyer_maker,
    CASE
        WHEN is_buyer_maker THEN 'SELL'
        ELSE 'BUY'
    END AS trade_side,
    year,
    month,
    day,
    hour
FROM {{ ref('stg_market_data') }}

{% if is_incremental() %}
WHERE event_timestamp > (SELECT max(event_timestamp) FROM {{ this }})
{% endif %}
