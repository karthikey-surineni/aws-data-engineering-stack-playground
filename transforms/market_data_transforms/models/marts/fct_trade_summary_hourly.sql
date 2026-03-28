{{ config(
    materialized='incremental',
    table_type='iceberg',
    format='parquet',
    incremental_strategy='append',
    on_schema_change='append_new_columns',
    partitioned_by=['month(trade_hour)']
) }}

WITH hourly_agg AS (
    SELECT
        symbol,
        date_trunc('hour', event_timestamp) AS trade_hour,
        count(*) AS trade_count,
        sum(quantity) AS total_quantity,
        sum(price_usd * quantity) AS total_volume_usd,
        avg(price_usd) AS avg_price_usd,
        min(price_usd) AS low_price_usd,
        max(price_usd) AS high_price_usd,
        min(price_usd) AS open_price_usd,
        max(price_usd) AS close_price_usd,
        max(price_usd) - min(price_usd) AS price_range_usd,
        sum(CASE WHEN is_buyer_maker THEN quantity ELSE 0 END) AS sell_quantity,
        sum(CASE WHEN NOT is_buyer_maker THEN quantity ELSE 0 END) AS buy_quantity
    FROM {{ ref('fct_trades') }}

    {% if is_incremental() %}
    WHERE event_timestamp > (SELECT max(trade_hour) FROM {{ this }})
    {% endif %}

    GROUP BY 1, 2
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['symbol', 'trade_hour']) }} AS summary_id,
    symbol,
    trade_hour,
    trade_count,
    total_quantity,
    total_volume_usd,
    avg_price_usd,
    low_price_usd,
    high_price_usd,
    open_price_usd,
    close_price_usd,
    price_range_usd,
    buy_quantity,
    sell_quantity,
    CASE
        WHEN total_quantity > 0
        THEN buy_quantity / total_quantity
        ELSE 0
    END AS buy_ratio
FROM hourly_agg
