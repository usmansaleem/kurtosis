#!/bin/bash

set -euo pipefail

# Function to extract RPC port from Kurtosis service inspect output
get_rpc_port() {
  local service_name="$1"
  kurtosis service inspect -o json my-testnet "$service_name" | jq -r '.public_ports.rpc.number'
}

# Determine Geth RPC port dynamically
GETH_RPC_PORT=$(get_rpc_port "el-1-geth-teku")

# Construct RPC URL
RPC_URL="http://127.0.0.1:$GETH_RPC_PORT"

# Declare other variables
# See https://github.com/ethpandaops/ethereum-package/blob/main/src/prelaunch_data_generator/genesis_constants/genesis_constants.star
PRIVATE_KEY="04b9f63ecf84210c5366c66d68fa1f5da1fa4f634fad6dfc86178e4d79ff9e59"
SCRIPT_PATH="./script/DeployNestedContracts.s.sol"

# Navigate to the contracts directory
cd contracts || { echo "Failed to cd into contracts directory"; exit 1; }

# Run the forge script command
forge script "$SCRIPT_PATH" --broadcast --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"