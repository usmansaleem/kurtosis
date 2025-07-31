#!/bin/bash
# run_call_tracer_tests.sh

set -euo pipefail

echo "Call Tracer Test Suite"
echo "======================"

# See for predefined accounts (account 20):
# https://github.com/ethpandaops/ethereum-package/blob/main/src/prelaunch_data_generator/genesis_constants/genesis_constants.star
# Configuration
PRIVATE_KEY="04b9f63ecf84210c5366c66d68fa1f5da1fa4f634fad6dfc86178e4d79ff9e59"

# Test scenarios to run
#SCENARIOS=(
#    "SimpleTransfer"
#    "CreateContract"
#    "SimpleContractCall"
#    "ContractCall"
#    "NestedContractCall"
#)
SCENARIOS=(
    "SimpleTransfer"
)

# Function to extract RPC port
get_rpc_port() {
    local service_name="$1"
    kurtosis service inspect -o json my-testnet "$service_name" | jq -r '.public_ports.rpc.number'
}

# Get RPC ports
echo "Getting RPC ports..."
GETH_RPC_PORT=$(get_rpc_port "el-1-geth-teku")
BESU_RPC_PORT=$(get_rpc_port "el-2-besu-teku")

GETH_RPC_URL="http://127.0.0.1:$GETH_RPC_PORT"
BESU_RPC_URL="http://127.0.0.1:$BESU_RPC_PORT"

echo "Besu RPC: $BESU_RPC_URL"
echo "Geth RPC: $GETH_RPC_URL"

# Create output directories
mkdir -p output/scenarios

# Function to extract transaction hash from forge JSON output
extract_tx_hash() {
    local output="$1"

    # Extract tx_hash from the JSON output
    local tx_hash=$(echo "$output" | jq -r 'select(.tx_hash != null) | .tx_hash' 2>/dev/null | head -1)

    if [ -n "$tx_hash" ] && [ "$tx_hash" != "null" ]; then
        echo "$tx_hash"
        return 0
    fi

    # Fallback: try to extract using grep
    tx_hash=$(echo "$output" | grep -o '"tx_hash":"0x[a-fA-F0-9]\{64\}"' | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)

    if [ -n "$tx_hash" ]; then
        echo "$tx_hash"
        return 0
    fi

    echo "ERROR: Could not extract transaction hash"
    return 1
}

# Function to get call tracer result
get_call_tracer() {
    local tx_hash="$1"
    local rpc_url="$2"
    local output_file="$3"

    local payload=$(cat <<EOF
{
  "jsonrpc": "2.0",
  "method": "debug_traceTransaction",
  "params": [
    "$tx_hash",
    {
      "tracer": "callTracer"
    }
  ],
  "id": 1
}
EOF
)

    echo "=== JSON-RPC Request ==="
    echo "$payload" | jq .
    echo "========================"
    echo "Sending to: $rpc_url"
    echo "Output file: $output_file"
    echo ""

    curl -s -X POST \
        -H "Content-Type: application/json" \
        --data "$payload" \
        "$rpc_url" | jq . > "$output_file"
}

# Function to run a single scenario
run_scenario() {
    local scenario="$1"
    echo ""
    echo "========================================="
    echo "Running Scenario: $scenario"
    echo "========================================="

    cd contracts

    # Run on Geth
    echo ""
    echo "--- Running on Geth ---"
    GETH_OUTPUT=$(forge script "script/${scenario}.s.sol" \
        --rpc-url "$GETH_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --slow \
        --json \
        --broadcast 2>&1)

    # Print output prettily if it's valid JSON
    if echo "$GETH_OUTPUT" | jq . > /dev/null 2>&1; then
        echo "$GETH_OUTPUT" | jq .
    else
        echo "$GETH_OUTPUT"
    fi
    GETH_TX_HASH=$(extract_tx_hash "$GETH_OUTPUT")
    echo "Geth TX Hash: $GETH_TX_HASH"

    cd ..

    # Get call tracer results
    echo ""
    echo "--- Getting Call Tracer Results ---"
    get_call_tracer "$GETH_TX_HASH" "$BESU_RPC_URL" "output/scenarios/${scenario}_besu.json"
    get_call_tracer "$GETH_TX_HASH" "$GETH_RPC_URL" "output/scenarios/${scenario}_geth.json"

    # Quick comparison
    echo "--- Quick Comparison ---"
    BESU_GAS=$(jq -r '.result.gasUsed // "null"' "output/scenarios/${scenario}_besu.json")
    GETH_GAS=$(jq -r '.result.gasUsed // "null"' "output/scenarios/${scenario}_geth.json")

    BESU_TYPE=$(jq -r '.result.type // "null"' "output/scenarios/${scenario}_besu.json")
    GETH_TYPE=$(jq -r '.result.type // "null"' "output/scenarios/${scenario}_geth.json")

    echo "Gas Used - Besu: $BESU_GAS, Geth: $GETH_GAS"
    echo "Call Type - Besu: $BESU_TYPE, Geth: $GETH_TYPE"

    if [ "$BESU_GAS" = "$GETH_GAS" ] && [ "$BESU_TYPE" = "$GETH_TYPE" ]; then
        echo "PASS: $scenario - Results match!"
        return 0
    else
        echo "FAIL: $scenario - Results differ!"
        return 1
    fi
}

# Deploy contracts first (only needed for NestedCalls scenario)
# Only deploy on Geth, it will be available on Besu as well
echo ""
echo "========================================="
echo "Deploying Contracts"
echo "========================================="
cd contracts

echo "Deploying Contracts to Geth..."
forge script script/DeployNestedContracts.s.sol \
    --rpc-url "$GETH_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast

cd ..

# Run all scenarios
PASSED=0
TOTAL=0

for scenario in "${SCENARIOS[@]}"; do
    if run_scenario "$scenario"; then
        ((PASSED++))
    fi
    ((TOTAL++))
done

# Summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Passed: $PASSED/$TOTAL scenarios"

if [ $PASSED -eq $TOTAL ]; then
    echo "SUCCESS: All tests passed!"
    exit 0
else
    echo "FAILURE: Some tests failed. Check output/scenarios/ for details."
    exit 1
fi