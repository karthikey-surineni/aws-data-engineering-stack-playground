# Skill: AWS Infrastructure Management & Inspection

## Description
This skill allows you to use the AWS Command Line Interface (CLI) to verify data ingestion, inspect Kinesis streams, and manage S3 buckets.

## Permitted Commands
You are authorized to execute read and write `aws` CLI commands. Examples include:
*   `aws s3 ls s3://<bucket-name>/` - To verify raw data has landed in the Bronze layer.
*   `aws kinesis list-streams` - To confirm the data streams are active.
*   `aws kinesis describe-stream --stream-name <name>` - To check shard capacity.
*   `aws athena start-query-execution` - To run test SQL queries against the resulting Iceberg tables.

## Instructions for the Agent
*   Use this skill to autonomously verify that your Python ingestion scripts or Firehose pipelines are successfully writing data to AWS. 
*   If a script claims to have sent data, you MUST use the AWS CLI to verify its existence in S3 or Kinesis before marking a task as complete.