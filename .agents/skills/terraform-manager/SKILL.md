# Skill: Terraform Infrastructure Management

## Description
This skill allows you to use Terraform to provision, modify, and destroy AWS infrastructure required for the Data Lakehouse (e.g., Kinesis, Firehose, S3, Athena).

## Prerequisites
* Terraform CLI must be installed locally.
* AWS credentials must be configured locally.
* A `provider.tf` file must exist defining the AWS provider.

## Permitted Commands
You are authorized to execute the following commands in the terminal within the `terraform/` directory:
* `terraform init` - To initialize the working directory and download providers.
* `terraform fmt` - To format the configuration files.
* `terraform validate` - To check configuration validity.
* `terraform plan` - To preview infrastructure changes.
* `terraform apply -auto-approve` - To provision the infrastructure.
* `terraform destroy -auto-approve` - To tear down the infrastructure when the PoC is complete.

## Instructions for the Agent
* Always run `terraform fmt` and `terraform validate` before attempting to plan or apply.
* Review the output of `terraform plan` to ensure it aligns with the architectural constraints before applying.