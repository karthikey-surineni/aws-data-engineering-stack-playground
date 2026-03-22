FROM python:3.11-slim

# Install system dependencies for Athena/dbt
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install dbt-athena
RUN pip install --no-cache-dir dbt-athena-community

# Copy dbt project files
COPY market_data_transforms/ /app/

# Set up dbt profiles directory
RUN mkdir -p /root/.dbt
COPY market_data_transforms/profiles.yml /root/.dbt/profiles.yml

# Default command to run dbt
ENTRYPOINT ["dbt"]
CMD ["run"]
