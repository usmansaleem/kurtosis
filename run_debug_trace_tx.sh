#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <tx_hash>"
  echo
  echo "Example:"
  echo "  $0 0x1234abcd…"
  exit 1
}

# Check if at least 1 argument (tx_hash) is provided
if [ "$#" -lt 1 ]; then
  usage
fi

# Assign the transaction hash
TX_HASH="$1"

# Function to extract RPC port from Kurtosis service inspect output
get_rpc_port() {
  local service_name="$1"
  kurtosis service inspect -o json my-testnet "$service_name" | jq -r '.public_ports.rpc.number'
}

# Determine Geth and Besu RPC ports dynamically
GETH_RPC_PORT=$(get_rpc_port "el-1-geth-teku")
BESU_RPC_PORT=$(get_rpc_port "el-2-besu-teku")

# Make sure output directory exists
mkdir -p output

# Build the JSON payload
#PAYLOAD=$(jq -n --arg hash "$TX_HASH" '{
#  jsonrpc: "2.0",
#  method:  "debug_traceTransaction",
#  params:  [
#    $hash,
#    {
#      enableMemory: true,
#      disableStack: false,
#      disableStorage: false,
#      enableReturnData: true,
#    }
#  ],
#  id: 1
#}')

PAYLOAD=$(jq -n --arg hash "$TX_HASH" '{
  jsonrpc: "2.0",
  method:  "debug_traceTransaction",
  params:  [
    $hash,
    {
      tracer:       "callTracer",
      tracerConfig: { onlyTopCall: false }
    }
  ],
  id: 1
}')

echo "=== JSON-RPC Request ==="
echo "$PAYLOAD" | jq .
echo "========================"
echo

# Trace on Geth
echo "Tracing on Geth (port $GETH_RPC_PORT)…"
curl -s -X POST \
     -H "Content-Type: application/json" \
     --data "$PAYLOAD" \
     http://localhost:"$GETH_RPC_PORT" \
  | jq . \
  > output/geth_output.json

# Trace on Besu
echo "Tracing on Besu (port $BESU_RPC_PORT)…"
curl -s -X POST \
     -H "Content-Type: application/json" \
     --data "$PAYLOAD" \
     http://localhost:"$BESU_RPC_PORT" \
  | jq . \
  > output/besu_output.json

echo "Done. Results saved to output/geth_output.json and output/besu_output.json"