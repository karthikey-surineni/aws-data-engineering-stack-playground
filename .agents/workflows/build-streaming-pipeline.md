# Workflow: Build AWS Streaming Pipeline

**Description:** Orchestrates the end-to-end creation of a real-time data streaming pipeline on AWS, enforcing Terraform for IaC and strict Python linting.

**Instructions for the Agent:**
When this workflow is invoked, transition into Planning Mode to generate an Implementation Plan and Task List based on the following multi-agent orchestration steps:

## Phase 1: Architecture & Security Review
- **Task:** Draft a Technical Design Document (TDD) for a pipeline that ingests live cryptocurrency trades (e.g., via Binance WebSocket) into AWS Kinesis, and uses Kinesis Firehose to land the raw data into an Amazon S3 Bronze layer.
- **Constraints:** AWS only. Default networking (no custom VPCs).
- **Delegation:** Invoke **@security-reviewer.md** to review the TDD. The reviewer must ensure all IAM policies follow the principle of least privilege.
- **Gate:** Do not proceed to implementation until the Security Reviewer formally approves the TDD.

## Phase 2: Infrastructure as Code (IaC)
- **Delegation:** Invoke **@terraform-engineer.md** to write the required Terraform files (`main.tf`, `variables.tf`, `outputs.tf`) to provision the Kinesis Stream, Firehose Delivery Stream, S3 Bucket, and IAM Roles.
- **Verification:** Invoke **@qa-engineer.md** to run `terraform validate` and `terraform plan`.
- **Gate:** Do not proceed until the QA Engineer reports a successful plan without errors.

## Phase 3: Pipeline Compute (Producer)
- **Delegation:** Invoke **@python-dbt-engineer.md** to write the local Python producer script (`producer.py`).
- **Constraints:** Python 3.13+, use `uv` for dependency management, and `ruff` for linting.
- **Verification:** Invoke **@qa-engineer.md** to run `uv run ruff check .` and execute any basic mock tests.
- **Gate:** Ensure all linting checks pass before marking the workflow as complete.