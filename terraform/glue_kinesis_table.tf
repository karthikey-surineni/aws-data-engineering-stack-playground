resource "aws_glue_catalog_table" "kinesis_raw_trades" {
  name          = "kinesis_raw_trades"
  database_name = aws_glue_catalog_database.market_data_db.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "kinesis"
    "typeOfData"     = "kinesis"
    "streamName"     = aws_kinesis_stream.market_data_stream.name
    "region"         = var.aws_region
  }

  storage_descriptor {
    location      = aws_kinesis_stream.market_data_stream.name
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "ignore.malformed.json" = "true"
      }
    }

    columns {
      name = "s"
      type = "string"
    }
    columns {
      name = "p"
      type = "string"
    }
    columns {
      name = "T"
      type = "bigint"
    }
  }
}
