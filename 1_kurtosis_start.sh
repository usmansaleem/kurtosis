#!/usr/bin/env bash
set -euo pipefail

# ------------------------
# Config
# ------------------------
ENCLAVE="${ENCLAVE:-my-testnet}"
PKG="${PKG:-github.com/ethpandaops/ethereum-package}"
ARGS_SRC="${ARGS_SRC:-./minimal-pectra.yaml}"   # keep 'hyperledger/besu:latest' in here

# ------------------------
# Optional Besu tag (positional or --tag= / -t)
# ------------------------
TAG="${TAG:-}"
if (($# > 0)); then
  case "${1:-}" in
    --tag=*) TAG="${1#*=}"; shift ;;
    -t)      TAG="${2-}";   shift 2 || true ;;
    *)       TAG="$1";      shift ;;
  esac
fi

# ------------------------
# Prepare args file in SAME DIR as source (to keep relative paths working)
# ------------------------
ARGS_FILE="$ARGS_SRC"
TMP_FILE=""

if [[ -n "${TAG}" && "${TAG}" != "latest" ]]; then
  if [[ ! -f "$ARGS_SRC" ]]; then
    echo "ERROR: Args file not found: $ARGS_SRC" >&2
    exit 1
  fi
  SRC_DIR="$(cd "$(dirname "$ARGS_SRC")" && pwd)"
  SRC_BASE="$(basename "$ARGS_SRC")"
  TMP_FILE="${SRC_DIR}/.${SRC_BASE}.tag_${TAG}.$$"

  # Replace only the exact token 'hyperledger/besu:latest'
  sed 's|hyperledger/besu:latest|hyperledger/besu:'"$TAG"'|g' "$ARGS_SRC" > "$TMP_FILE"
  ARGS_FILE="$TMP_FILE"
  echo "Using temporary args file with Besu tag ${TAG}: $ARGS_FILE"
fi

cleanup() { [[ -n "${TMP_FILE}" && -f "${TMP_FILE}" ]] && rm -f "${TMP_FILE}" || true; }
trap cleanup EXIT

echo "Starting kurtosis enclave ${ENCLAVE} with package ${PKG}"
echo "Args file: ${ARGS_FILE}"

# --- helper: does enclave exist? ---
enclave_exists() { kurtosis enclave inspect "${ENCLAVE}" >/dev/null 2>&1; }

# --- helper: discover a Teku CL service name ---
discover_teku_service() {
  local enclave="$1"
  # Try common names first (ethpandaops conventions)
  for s in cl-1-teku-geth cl-2-teku-besu cl-1-teku cl-2-teku; do
    if kurtosis port print "$enclave" "$s" http >/dev/null 2>&1; then
      echo "$s"; return 0
    fi
  done
  # Fallback: list services & pick the first CL with "teku" in the name
  if kurtosis enclave inspect "$enclave" >/dev/null 2>&1; then
    local svc
    svc=$(kurtosis service list "$enclave" 2>/dev/null | awk 'NR>1 {print $1}' | grep -E '^cl-.*teku' | head -1 || true)
    [[ -n "$svc" ]] && { echo "$svc"; return 0; }
  fi
  return 1
}

# --- helper: read configured genesis_delay from YAML ---
parse_genesis_delay() {
  local file="$1"
  [[ -f "$file" ]] || { echo ""; return 0; }
  awk -F: '
    /^[[:space:]]*genesis_delay[[:space:]]*:/ { gsub(/[[:space:]]/,"",$2); print $2; found=1; exit }
    END { if (!found) print "" }
  ' "$file"
}

# --- helper: wait for beacon genesis using CL beacon API (uses full URL) ---
wait_for_beacon_genesis() {
  local enclave="${1:-my-testnet}"
  local cl_service="${2:-cl-1-teku-geth}"
  local port_name="${3:-http}"

  # Full URL (e.g. http://127.0.0.1:33001)
  local cl_url
  if ! cl_url=$(kurtosis port print "$enclave" "$cl_service" "$port_name" 2>/dev/null); then
    echo "WARN: could not find CL URL for ${cl_service} in ${enclave}; falling back to sleep" >&2
    return 2
  fi

  # Get genesis_time
  local genesis_ts now wait_s
  genesis_ts=$(curl -s "${cl_url}/eth/v1/beacon/genesis" | jq -r '.data.genesis_time // empty')
  if [[ ! "$genesis_ts" =~ ^[0-9]+$ ]]; then
    echo "WARN: CL genesis endpoint unavailable; falling back to sleep" >&2
    return 2
  fi

  now=$(date +%s)
  wait_s=$(( genesis_ts - now ))
  if (( wait_s > 0 )); then
    echo "Waiting ~${wait_s}s until beacon genesis (${genesis_ts})…"
    sleep "$wait_s"
  else
    echo "Beacon genesis already reached (${genesis_ts}); continuing."
  fi
}

# --- helper: robust EL RPC URL discovery ---
get_rpc_url() {
  local enclave="${1:-$ENCLAVE}"
  local service="$2"
  # Prefer kurtosis' own URL printer
  for pname in rpc http http-rpc; do
    if url=$(kurtosis port print "$enclave" "$service" "$pname" 2>/dev/null); then
      [[ -n "$url" ]] && { echo "$url"; return 0; }
    fi
  done
  # Fallback: construct URL from service inspect (assumes localhost)
  local info port
  if info=$(kurtosis service inspect -o json "$enclave" "$service" 2>/dev/null); then
    port=$(jq -r '.public_ports.rpc.number // .public_ports.http.number // empty' <<<"$info")
    [[ -n "$port" ]] && { echo "http://127.0.0.1:${port}"; return 0; }
  fi
  echo "ERROR: no rpc/http public port found for service '$service' in enclave '$enclave'" >&2
  return 1
}

# --- helper: discover EL services (geth/besu) ---
discover_el_service() {
  local enclave="$1" kind="$2"
  local candidates
  case "$kind" in
    geth) candidates="el-1-geth-teku el-1-geth";;
    besu) candidates="el-2-besu-teku el-2-besu";;
    *)    candidates="";;
  esac
  for s in $candidates; do
    if kurtosis service inspect "$enclave" "$s" >/dev/null 2>&1; then
      echo "$s"; return 0
    fi
  done
  local patt=""
  [[ "$kind" == "geth" ]] && patt='^el-.*geth' || patt='^el-.*besu'
  if kurtosis enclave inspect "$enclave" >/dev/null 2>&1; then
    local svc
    svc=$(kurtosis service list "$enclave" 2>/dev/null | awk 'NR>1 {print $1}' | grep -E "$patt" | head -1 || true)
    [[ -n "$svc" ]] && { echo "$svc"; return 0; }
  fi
  return 1
}

# --- helper: post-genesis, wait for EL RPC to respond to eth_blockNumber ---
wait_for_el_ready() {
  local rpc_url="$1"
  local label="$2"
  echo "Waiting for ${label} at ${rpc_url} to respond to eth_blockNumber…"
  for i in {1..60}; do
    if curl -sS -H 'Content-Type: application/json' \
      -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
      "$rpc_url" | jq -e '.result' >/dev/null 2>&1; then
      echo "${label} is responding."
      return 0
    fi
    sleep 2
  done
  echo "WARN: ${label} did not respond within timeout." >&2
  return 1
}

# Ensure enclave exists
if enclave_exists; then
  echo "Enclave '${ENCLAVE}' already exists."
else
  echo "Enclave '${ENCLAVE}' not found; creating..."
  kurtosis enclave add --name "${ENCLAVE}"
fi

# Run the package
echo "Launching package ${PKG} in enclave ${ENCLAVE} with args: ${ARGS_FILE}"
kurtosis run --enclave "${ENCLAVE}" "${PKG}" --args-file "${ARGS_FILE}"

# === Deterministic wait for genesis ===
CL_SVC="${CL_SVC:-$(discover_teku_service "$ENCLAVE" || true)}"
if [[ -n "${CL_SVC:-}" ]]; then
  echo "Detected CL service: ${CL_SVC}"
  if ! wait_for_beacon_genesis "$ENCLAVE" "$CL_SVC" "http"; then
    # Fallback to configured genesis_delay in ARGS_FILE, or 120s default
    DELAY="$(parse_genesis_delay "$ARGS_FILE")"
    [[ -z "${DELAY}" ]] && DELAY="120"
    echo "Falling back to configured genesis_delay (${DELAY}s)…"
    sleep "$DELAY"
  fi
else
  echo "WARN: Could not detect CL service; falling back to configured genesis_delay."
  DELAY="$(parse_genesis_delay "$ARGS_FILE")"
  [[ -z "${DELAY}" ]] && DELAY="120"
  echo "Sleeping ${DELAY}s…"
  sleep "$DELAY"
fi

echo "Genesis reached. Discovering EL RPC endpoints…"

# Discover EL services and RPC URLs
GETH_SVC="${GETH_SVC:-$(discover_el_service "$ENCLAVE" geth || true)}"
BESU_SVC="${BESU_SVC:-$(discover_el_service "$ENCLAVE" besu || true)}"

if [[ -n "${GETH_SVC:-}" ]]; then
  GETH_RPC_URL="$(get_rpc_url "$ENCLAVE" "$GETH_SVC")" || true
  if [[ -n "${GETH_RPC_URL:-}" ]]; then
    echo "Geth RPC: ${GETH_RPC_URL} (service ${GETH_SVC})"
    wait_for_el_ready "$GETH_RPC_URL" "Geth"
  else
    echo "WARN: Could not resolve RPC URL for ${GETH_SVC}" >&2
  fi
else
  echo "WARN: Could not detect Geth EL service" >&2
fi

if [[ -n "${BESU_SVC:-}" ]]; then
  BESU_RPC_URL="$(get_rpc_url "$ENCLAVE" "$BESU_SVC")" || true
  if [[ -n "${BESU_RPC_URL:-}" ]]; then
    echo "Besu RPC: ${BESU_RPC_URL} (service ${BESU_SVC})"
    wait_for_el_ready "$BESU_RPC_URL" "Besu"
  else
    echo "WARN: Could not resolve RPC URL for ${BESU_SVC}" >&2
  fi
else
  echo "WARN: Could not detect Besu EL service" >&2
fi

echo "Services should now be ready!"
