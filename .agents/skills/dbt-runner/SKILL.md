# Skill: dbt Pipeline Execution

## Description
This skill enables you to execute dbt (Data Build Tool) commands locally to transform data in the Bronze S3 layer into Apache Iceberg tables in the Silver S3 layer.

## Prerequisites
*   The `dbt-athena-community` adapter must be installed in the local Python environment.
*   AWS credentials must be configured locally to allow dbt to communicate with Athena and S3.

## Permitted Commands
You are authorized to execute the following commands in the terminal within the dbt project directory:
*   `dbt debug` - To verify the connection to Athena/AWS.
*   `dbt run` - To execute the SQL models and build the Iceberg tables.
*   `dbt test` - To run data quality and schema tests against the built tables.
*   `dbt clean` - To clear the target directory if recompilation is necessary.

## Instructions for the Agent
1. Always run `dbt debug` first if this is a new workspace to ensure AWS permissions are correct.
2. After running `dbt run`, parse the terminal output to confirm that the Iceberg tables were successfully created or updated.
3. If a `dbt run` fails, analyze the compiled SQL in the `target/compiled/` directory before attempting a fix.