import asyncio
import json
import logging
import os
import uuid
from typing import Any, Dict

import boto3
import websockets

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

# Constants
BINANCE_WS_URL = "wss://stream.binance.com:9443/ws/btcusdt@trade"
KINESIS_STREAM_NAME = os.environ.get("KINESIS_STREAM_NAME", "market-data-binance-stream")
AWS_REGION = os.environ.get("AWS_REGION", "ap-southeast-2")

class BinanceProducer:
    def __init__(self, stream_name: str, region_name: str):
        self.stream_name = stream_name
        self.kinesis_client = boto3.client("kinesis", region_name=region_name)
        logger.info(f"Initialized BinanceProducer for Kinesis stream: {self.stream_name}")

    def put_record(self, data: Dict[str, Any]):
        """Pushes a single record to Kinesis."""
        try:
            partition_key = str(data.get("E", uuid.uuid4()))  # Use event time or random UUID as partition key
            response = self.kinesis_client.put_record(
                StreamName=self.stream_name,
                Data=json.dumps(data).encode("utf-8"),
                PartitionKey=partition_key
            )
            logger.debug(f"Pushed to Kinesis: ShardId={response['ShardId']}, SequenceNumber={response['SequenceNumber']}")
        except Exception as e:
            logger.error(f"Error pushing to Kinesis: {e}")

    async def stream_data(self):
        """Connects to Binance WS and streams data to Kinesis."""
        logger.info(f"Connecting to Binance WebSocket at {BINANCE_WS_URL}...")
        async for websocket in websockets.connect(BINANCE_WS_URL):
            try:
                logger.info("Connected to Binance WebSocket!")
                async for message in websocket:
                    data = json.loads(message)
                    self.put_record(data)
            except websockets.ConnectionClosed:
                logger.warning("WebSocket connection closed. Reconnecting...")
                await asyncio.sleep(5)
            except Exception as e:
                logger.error(f"Unexpected error in WS stream: {e}")
                await asyncio.sleep(5)

if __name__ == "__main__":
    producer = BinanceProducer(stream_name=KINESIS_STREAM_NAME, region_name=AWS_REGION)
    try:
        asyncio.run(producer.stream_data())
    except KeyboardInterrupt:
        logger.info("Producer stopped by user.")
