resource "aws_glue_catalog_table" "raw_trades" {
  name          = "raw_trades"
  database_name = aws_glue_catalog_database.market_data_db.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"            = "json"
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2024,2030"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "1,12"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "projection.hour.type"      = "integer"
    "projection.hour.range"     = "0,23"
    "storage.location.template" = "s3://${aws_s3_bucket.bronze_bucket.bucket}/raw/binance/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.bronze_bucket.bucket}/raw/binance/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "ignore.malformed.json" = "true"
        # Binance WebSocket trade events use E / T / M; Hive column names must be mapped explicitly.
        "mapping.e_time"   = "E"
        "mapping.t_time"   = "T"
        "mapping.m_ignore" = "M"
      }
    }

    columns {
      name    = "e"
      type    = "string"
      comment = "Event type"
    }
    columns {
      name    = "e_time" # Mapped from E
      type    = "bigint"
      comment = "Event time"
    }
    columns {
      name    = "s"
      type    = "string"
      comment = "Symbol"
    }
    columns {
      name    = "t"
      type    = "bigint"
      comment = "Trade ID"
    }
    columns {
      name    = "p"
      type    = "string"
      comment = "Price"
    }
    columns {
      name    = "q"
      type    = "string"
      comment = "Quantity"
    }
    columns {
      name    = "b"
      type    = "bigint"
      comment = "Buyer order ID"
    }
    columns {
      name    = "a"
      type    = "bigint"
      comment = "Seller order ID"
    }
    columns {
      name    = "t_time" # Mapped from T
      type    = "bigint"
      comment = "Trade time"
    }
    columns {
      name    = "m"
      type    = "boolean"
      comment = "Is the buyer the market maker?"
    }
    columns {
      name    = "m_ignore" # Mapped from M
      type    = "boolean"
      comment = "Ignore"
    }
  }

  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
  partition_keys {
    name = "hour"
    type = "string"
  }
}
