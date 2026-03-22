# Glue Catalog Database for dbt Athena
resource "aws_glue_catalog_database" "market_data_db" {
  name        = "${replace(var.project_prefix, "-", "_")}_db"
  description = "Glue Catalog Database for raw market data in S3."
}

# Dedicated S3 Bucket for Athena Query Results
resource "aws_s3_bucket" "athena_query_results" {
  bucket        = "${var.s3_bucket_name}-athena-results"
  force_destroy = true
}

# Athena Workgroup for dbt
resource "aws_athena_workgroup" "dbt_workgroup" {
  name = "${replace(var.project_prefix, "-", "_")}_dbt_workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_query_results.bucket}/"
    }
  }

  force_destroy = true
}

output "glue_database_name" {
  description = "The name of the Glue Database for dbt Athena"
  value       = aws_glue_catalog_database.market_data_db.name
}

output "athena_workgroup_name" {
  description = "The Athena Workgroup Name for dbt"
  value       = aws_athena_workgroup.dbt_workgroup.name
}
