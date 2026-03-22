import sys
import json
from datetime import datetime, timezone
import redis
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql.functions import col, window, avg, from_unixtime, from_json
from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    LongType,
    BooleanType,
)

# Fetch job arguments
args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "REDIS_HOST", "REDIS_PORT", "AWS_REGION", "TempDir", "STREAM_ARN"],
)
redis_host = args["REDIS_HOST"]
redis_port = int(args["REDIS_PORT"])
aws_region = args["AWS_REGION"]
stream_arn = args["STREAM_ARN"]

# Initialize GlueContext
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

spark.sparkContext.setLogLevel("WARN")
spark.conf.set("spark.sql.caseSensitive", "true")

# Glue 4.0 (Spark 3.3) handles S3 natively. 
# We remove manual AbstractFileSystem overrides to avoid conflicts with Glue's managed environment.

# STREAM_ARN from job args avoids boto3 STS: global sts.amazonaws.com often times out
# from VPC jobs; regional STS would work but passing the ARN from Terraform is simpler.
# spark-sql-kinesis defaults to us-east-1; regional URL is required behind a VPC ENI.
kinesis_endpoint = f"https://kinesis.{aws_region}.amazonaws.com"
print(f"Kinesis stream ARN: {stream_arn}")
print(f"Kinesis endpoint: {kinesis_endpoint}")

# Glue create_data_frame.from_options wraps the Kinesis plan so `data` is not resolvable in
# select/expr. Use the connector directly via readStream (same spark-sql-kinesis.jar).
_stream_name = stream_arn.rpartition("/")[-1]
_trade_schema = StructType(
    [
        StructField("e", StringType(), True),
        StructField("E", LongType(), True),
        StructField("s", StringType(), True),
        StructField("t", LongType(), True),
        StructField("p", StringType(), True),
        StructField("q", StringType(), True),
        StructField("b", LongType(), True),
        StructField("a", LongType(), True),
        StructField("T", LongType(), True),
        StructField("m", BooleanType(), True),
        StructField("M", BooleanType(), True),
    ]
)

kinesis_df = (
    spark.readStream.format("kinesis")
    .option("streamName", _stream_name)
    .option("endpointUrl", kinesis_endpoint)
    .option("startingPosition", "TRIM_HORIZON")
    .load()
)

trades_df = kinesis_df.select(
    from_json(col("data").cast("string"), _trade_schema).alias("_trade")
).select("_trade.*")

# Select and rename columns for clarity
# Binance 'T' is the trade time in milliseconds
# Binance 'p' is the price as a string
refined_df = trades_df.select(
    col("s").alias("symbol"),
    col("p").cast("double").alias("price"),
    col("T").alias("trade_time_ms")
)

parsed_df = (
    refined_df.withColumn("timestamp", from_unixtime(col("trade_time_ms") / 1000).cast("timestamp"))
    .filter(col("symbol").isNotNull())
    .filter(col("price").isNotNull())
)

# 10-second tumbling window average
agg_df = (
    parsed_df.withWatermark("timestamp", "10 seconds")
    .groupBy(window(col("timestamp"), "10 seconds"), col("symbol"))
    .agg(avg("price").alias("avg_price"))
)


def write_to_redis(batch_df, batch_id):
    """Write aggregated prices to ElastiCache Redis."""
    # -----------------------------------------------------------------------
    # DIAGNOSTIC: Print batch stats and first few rows
    # -----------------------------------------------------------------------
    count = batch_df.count()
    print(f"DEBUG: Batch {batch_id} initiated. Processing {count} row(s).")
    
    if count > 0:
        print("DEBUG: First row preview:")
        batch_df.show(1, truncate=False)
        
        # Original Redis logic...
        try:
            r = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)
            pipe = r.pipeline()
            now = datetime.now(timezone.utc).isoformat()

            # collect() is okay here because agg_df is small (one row per symbol)
            rows = batch_df.collect()
            for row in rows:
                key = f"avg_price:{row['symbol']}"
                value = json.dumps(
                    {
                        "timestamp": str(row["window"]["end"]),
                        "avg_price": row["avg_price"],
                        "batch_id": batch_id,
                        "updated_at": now,
                    }
                )
                pipe.set(key, value)
            pipe.execute()
            r.close()
            print(f"Batch {batch_id}: wrote {len(rows)} symbol(s) to Redis at {now}")
        except Exception as e:
            print(f"ERROR: Failed writing to Redis: {str(e)}")
    else:
        print("DEBUG: Batch was empty. Possible cause: parsing error or latest stream position skip.")


# SINK: Write the aggregated data into Redis using forEachBatch
# Durable checkpoint on S3; use s3a so Spark's checkpoint committer uses the Hadoop S3A FS.
_tmp = args["TempDir"].rstrip("/")
checkpoint_path = (
    ("s3a://" + _tmp[5:]) if _tmp.startswith("s3://") else _tmp
) + "/streaming-checkpoints/" + args["JOB_NAME"] + "/"
print(f"Streaming checkpoint: {checkpoint_path}")

query = (
    agg_df.writeStream
    .outputMode("update")
    .option("checkpointLocation", checkpoint_path)
    .foreachBatch(write_to_redis)
    .trigger(processingTime="10 seconds")
    .start()
)

query.awaitTermination()
job.commit()
