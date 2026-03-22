import sys
import redis
from awsglue.utils import getResolvedOptions

# Initialize Redis client using arguments passed to the Glue job
args = getResolvedOptions(sys.argv, ['REDIS_HOST', 'REDIS_PORT'])

redis_host = args['REDIS_HOST']
redis_port = int(args['REDIS_PORT'])

print(f"Connecting to Redis at {redis_host}:{redis_port}...")

try:
    r = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)
    
    # 1. Scan for the price average keys
    pattern = "avg_price:*"
    keys = r.keys(pattern)
    
    if keys:
        print(f"SUCCESS: Found metric(s) matching {pattern}")
        for k in keys:
            val = r.get(k)
            print(f"Key: {k} -> Value: {val}")
    else:
        print(f"WARNING: No keys matching '{pattern}' found in Redis yet.")
        
    # 2. List all keys (for discovery)
    all_keys = r.keys("*")
    print(f"Total keys in cluster: {len(all_keys)}")
    if all_keys:
        print(f"Keys: {all_keys}")

except Exception as e:
    print(f"ERROR: Failed to query Redis: {str(e)}")
    sys.exit(1)
