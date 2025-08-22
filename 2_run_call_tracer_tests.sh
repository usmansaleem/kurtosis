#!/bin/bash
# 2_run_call_tracer_tests.sh
# Run Foundry scenarios on Geth, then compare Geth vs Besu debug_traceTransaction (callTracer).

set -euo pipefail

echo "Call Tracer Test Suite"
echo "======================"

# ------------------------------
# Config
# ------------------------------

# Predefined dev key (account 20 in the Kurtosis package)
# https://github.com/ethpandaops/ethereum-package/blob/main/src/prelaunch_data_generator/genesis_constants/genesis_constants.star
PRIVATE_KEY="04b9f63ecf84210c5366c66d68fa1f5da1fa4f634fad6dfc86178e4d79ff9e59"

# Default scenarios (override by passing names as CLI args)
SCENARIOS=(
  "SimpleTransfer"
  "CreateContract"
  "SimpleContractCall"
  "ContractCall"
  "NestedContractCall"
  "HelperRevert"
  "Delegatecall"
  "PrecompileBlake2F"
  "PrecompileBn128Add"
  "PrecompileBn128Mul"
  "PrecompileBn128Pairing"
  "PrecompileECRecover"
  "PrecompileIdentity"
  "PrecompileModExp"
  "PrecompileRIPEMD160"
  "PrecompileSHA256"
)

# ------------------------------
# Helpers
# ------------------------------

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 2; }; }

check_deps() {
  require_cmd jq
  require_cmd curl
  require_cmd kurtosis
  require_cmd diff
  require_cmd forge
}

get_rpc_port() {
  local service_name="$1"
  kurtosis service inspect -o json my-testnet "$service_name" | jq -r '.public_ports.rpc.number'
}

# Normalize callTracer trees for meaningful diffs
normalize() {
  jq -S '
    def normCall:
      . as $c | {
        from, to, type, input, output, error, revertReason, gas, gasUsed, value,
        calls: (($c.calls // []) | map(normCall))
      } | with_entries(select(.value != null));
    normCall
  '
}

# Extract the **last** tx hash from Foundry output (handles multiple CREATEs then a call)
extract_tx_hash() {
  local output="$1"
  local tx_hash

  # Prefer structured JSON traversal
  tx_hash=$(echo "$output" \
    | jq -r '.. | .tx_hash? // .txHash? // .hash? // empty' 2>/dev/null \
    | grep -E '^0x[0-9a-fA-F]{64}$' \
    | tail -1)
  if [ -n "${tx_hash:-}" ]; then
    echo "$tx_hash"; return 0
  fi

  # Fallback: grep any 0x...64
  tx_hash=$(echo "$output" | grep -oE '0x[0-9a-fA-F]{64}' | tail -1)
  if [ -n "${tx_hash:-}" ]; then
    echo "$tx_hash"; return 0
  fi

  echo "ERROR: Could not extract transaction hash" >&2
  return 1
}

# Wait until a node indexes the tx
wait_for_tx() {
  local tx="$1" rpc="$2" tries="${3:-60}" sleep_s="${4:-1}"
  local payload
  payload=$(jq -cn --arg tx "$tx" '{jsonrpc:"2.0",id:1,method:"eth_getTransactionByHash",params:[$tx]}')
  for ((i=1;i<=tries;i++)); do
    if curl -s -H 'content-type: application/json' -d "$payload" "$rpc" | jq -e '.result != null' >/dev/null; then
      return 0
    fi
    sleep "$sleep_s"
  done
  return 1
}

# Call debug_traceTransaction with the callTracer (with error handling)
get_call_tracer() {
  local tx_hash="$1" rpc_url="$2" output_file="$3"

  local payload
  payload=$(jq -cn --arg tx "$tx_hash" '{jsonrpc:"2.0",id:1,method:"debug_traceTransaction",params:[$tx, {tracer:"callTracer"}]}')

  echo "=== JSON-RPC Request ==="
  echo "$payload" | jq .
  echo "========================"
  echo "Sending to: $rpc_url"
  echo "Output file: $output_file"
  echo ""

  local resp
  resp=$(curl -s -X POST -H "Content-Type: application/json" --data "$payload" "$rpc_url")

  # Write pretty JSON for inspection
  echo "$resp" | jq . > "$output_file"

  # Fail if RPC error present
  echo "$resp" | jq -e '.error | not' >/dev/null || {
    echo "RPC ERROR from $rpc_url: $(echo "$resp" | jq -r '.error.message // "unknown error"')" >&2
    return 1
  }

  # Ensure result exists
  echo "$resp" | jq -e '.result != null' >/dev/null || {
    echo "Missing .result in response from $rpc_url" >&2
    return 1
  }
}

run_scenario() {
  local scenario="$1"
  echo ""
  echo "========================================="
  echo "Running Scenario: $scenario"
  echo "========================================="

  pushd contracts >/dev/null

  echo ""
  echo "--- Running on Geth ---"
  GETH_OUTPUT=$(forge script "script/${scenario}.s.sol" \
      --rpc-url "$GETH_RPC_URL" \
      --private-key "$PRIVATE_KEY" \
      --slow \
      --json \
      --broadcast 2>&1)

  # Pretty print if JSON, otherwise print raw
#  if echo "$GETH_OUTPUT" | jq . >/dev/null 2>&1; then
#    echo "$GETH_OUTPUT" | jq .
#  else
#    echo "$GETH_OUTPUT"
#  fi

  GETH_TX_HASH=$(extract_tx_hash "$GETH_OUTPUT") || {
    echo "Failed to extract tx hash for $scenario"; popd >/dev/null; return 1; }
  echo "Geth TX Hash: $GETH_TX_HASH"

  popd >/dev/null

  echo ""
  echo "--- Waiting for tx on both clients ---"
  wait_for_tx "$GETH_TX_HASH" "$GETH_RPC_URL" 60 1 || { echo "Geth did not index tx"; return 1; }
  wait_for_tx "$GETH_TX_HASH" "$BESU_RPC_URL" 60 1 || { echo "Besu did not index tx"; return 1; }

  echo ""
  echo "--- Getting Call Tracer Results ---"
  get_call_tracer "$GETH_TX_HASH" "$BESU_RPC_URL" "output/scenarios/${scenario}_besu.json" || return 1
  get_call_tracer "$GETH_TX_HASH" "$GETH_RPC_URL" "output/scenarios/${scenario}_geth.json" || return 1

  echo "--- Quick Comparison ---"
  BESU_GAS=$(jq -r '.result.gasUsed // "null"' "output/scenarios/${scenario}_besu.json")
  GETH_GAS=$(jq -r '.result.gasUsed // "null"' "output/scenarios/${scenario}_geth.json")
  BESU_TYPE=$(jq -r '.result.type // "null"' "output/scenarios/${scenario}_besu.json")
  GETH_TYPE=$(jq -r '.result.type // "null"' "output/scenarios/${scenario}_geth.json")
  echo "Gas Used - Besu: $BESU_GAS, Geth: $GETH_GAS"
  echo "Call Type - Besu: $BESU_TYPE, Geth: $GETH_TYPE"

  echo "--- Normalized Diff (geth vs besu) ---"
  if diff -u \
      <(jq -S '.result' "output/scenarios/${scenario}_geth.json"  | normalize) \
      <(jq -S '.result' "output/scenarios/${scenario}_besu.json" | normalize); then
    echo "PASS: $scenario - Results match!"
    return 0
  else
    echo "FAIL: $scenario - Differences detected (see diff above)"
    return 1
  fi
}

# ------------------------------
# Main
# ------------------------------

check_deps

echo "Getting RPC ports from Kurtosis..."
GETH_RPC_PORT=$(get_rpc_port "el-1-geth-teku")
BESU_RPC_PORT=$(get_rpc_port "el-2-besu-teku")

GETH_RPC_URL="http://127.0.0.1:${GETH_RPC_PORT}"
BESU_RPC_URL="http://127.0.0.1:${BESU_RPC_PORT}"

echo "Besu RPC: $BESU_RPC_URL"
echo "Geth RPC: $GETH_RPC_URL"

mkdir -p output/scenarios
rm -f output/scenarios/*.json 2>/dev/null || true

# Allow selective run: ./script.sh SimpleTransfer HelperRevert
if [ "$#" -gt 0 ]; then
  SCENARIOS=("$@")
fi

# Deploy contracts needed for chained scenarios (only to Geth; Besu sees them via Kurtosis network)
echo ""
echo "========================================="
echo "Deploying Contracts"
echo "========================================="
pushd contracts >/dev/null
echo "Deploying Contracts to Geth..."
forge script script/DeployNestedContracts.s.sol \
  --rpc-url "$GETH_RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast
popd >/dev/null

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

if [ "$PASSED" -eq "$TOTAL" ]; then
  echo "SUCCESS: All tests passed!"
  exit 0
else
  echo "FAILURE: Some tests failed. Check output/scenarios/ for details."
  exit 1
fi
