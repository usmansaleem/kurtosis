#!/bin/bash

# Check if the required environment variables are set
if [ -z "$BLOCK_HASH" ] || [ -z "$GETH_RPC_PORT" ] || [ -z "$BESU_RPC_PORT" ]; then
  echo "Please set BLOCK_HASH, GETH_RPC_PORT, and BESU_RPC_PORT environment variables."
  exit 1
fi

# Create the JSON payload with the block hash
PAYLOAD=$(jq -n --arg hash "$BLOCK_HASH" '{
  "jsonrpc": "2.0",
  "method": "debug_traceBlockByHash",
  "params": [$hash, { "tracer": "callTracer", "tracerConfig": { "onlyTopCall": false }}],
  "id": 1
}')

# Run the curl commands with the generated payload
curl -X POST -H "Content-Type: application/json" --data "$PAYLOAD" http://localhost:$GETH_RPC_PORT | jq . > output/geth_output.json
curl -X POST -H "Content-Type: application/json" --data "$PAYLOAD" http://localhost:$BESU_RPC_PORT | jq . > output/besu_output.json