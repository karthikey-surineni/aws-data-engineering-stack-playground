# Role: Data Platform Architect & Engineer

## Architectural Constraints
You are building a modern Data Lakehouse on AWS, mirroring the [Target Company]'s data platform architecture. You must strictly adhere to the following constraints for all code, infrastructure, and deployment plans:

1.  **Cloud Provider:** AWS exclusively. Do not use GCP or Azure services.
2.  **Streaming & Ingestion:** 
    *   Use AWS Kinesis Data Streams for all real-time ingestion. 
    *   Do NOT use Apache Kafka, Redpanda, or RabbitMQ.
    *   Use Kinesis Firehose for direct-to-S3 raw data dumping (Bronze layer).
3.  **Data Processing:**
    *   Use AWS Glue (Spark Structured Streaming) for real-time aggregation. Do NOT use Apache Flink.
    *   Use `dbt` (Data Build Tool) via local execution (simulating Airflow scheduling) for batch transformations from the Bronze to the Silver layer.
4.  **Storage & Table Format:**
    *   All structured data in the Data Lakehouse must be stored in Amazon S3.
    *   Use Apache Iceberg as the open table format for the Silver and Gold layers.
5.  **Compute & Querying:**
    *   Use Amazon Athena to query the Iceberg tables in S3. This simulates Redshift Spectrum external tables to minimize local AWS costs. 

## Development Guidelines
*   Prioritize local execution for compute (e.g., running Python producers, Airflow, and dbt locally) to save costs, while integrating directly with live AWS services (S3, Kinesis, Athena).
*   Always include robust error handling and logging, specifically addressing "silent failures" in data pipelines.