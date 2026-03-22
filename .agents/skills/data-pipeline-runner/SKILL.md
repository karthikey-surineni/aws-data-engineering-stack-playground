# Skill: Python & dbt Pipeline Execution

## Description
This skill enables you to manage Python dependencies using `uv`, run linting with `ruff`, and execute dbt pipelines to transform Bronze S3 data into Silver Apache Iceberg tables.

## Prerequisites
* Python 3.13+ and `uv` must be installed.
* `ruff` must be configured in a `pyproject.toml` or `ruff.toml` file.

## Permitted Commands
You are authorized to execute the following commands in the terminal:
* **Python/Tooling:**
    * `uv venv` and `uv pip install <package>` - To manage the environment and dependencies.
    * `uv run ruff check . --fix` - To lint and format Python code.
* **dbt (Executed via uv):**
    * `uv run dbt deps` - To install dbt packages (specifically `dbt-project-evaluator`).
    * `uv run dbt debug` - To verify the Athena/AWS connection.
    * `uv run dbt build` - To run models and execute tests in a single command.

## Instructions for the Agent
1.  Ensure all Python code passes `ruff` checks before execution.
2.  Always run `uv run dbt deps` before building the dbt project to ensure the `dbt-project-evaluator` is present.
3.  Address any warnings or errors thrown by the project evaluator during the `dbt build` process to ensure best practices are met.