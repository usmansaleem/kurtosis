#!/bin/bash
set -euo pipefail

# ------------------------
# Config
# ------------------------
ENCLAVE="my-testnet"
ARTIFACT_NAME="besu_log4j"
LOCAL_LOG4J="./config/log4j2.xml"
PKG="github.com/ethpandaops/ethereum-package"
ARGS_SRC="./minimal-pectra.yaml"   # keep 'hyperledger/besu:latest' in here

# Optional Besu tag (positional or --tag= / -t)
TAG=""
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

cleanup() { [[ -n "${TMP_FILE}" ]] && rm -f "${TMP_FILE}" || true; }
trap cleanup EXIT

echo "Starting kurtosis enclave ${ENCLAVE} with ethereum-package..."

# --- helper: does enclave exist? ---
enclave_exists() { kurtosis enclave inspect "${ENCLAVE}" >/dev/null 2>&1; }

# Ensure enclave exists; upload files artifact ONLY on first create
if enclave_exists; then
  echo "Enclave '${ENCLAVE}' already exists."
else
  echo "Enclave '${ENCLAVE}' not found; creating..."
  kurtosis enclave add --name "${ENCLAVE}"
  echo "Uploading files artifact '${ARTIFACT_NAME}' from ${LOCAL_LOG4J}..."
  kurtosis files upload --name "${ARTIFACT_NAME}" "${ENCLAVE}" "${LOCAL_LOG4J}"
fi

# Run the package
echo "Launching package ${PKG} in enclave ${ENCLAVE} with args: ${ARGS_FILE}"
kurtosis run --enclave "${ENCLAVE}" "${PKG}" --args-file "${ARGS_FILE}"

echo "Waiting for 90 seconds for Genesis Time to initialize..."
sleep 90

echo "Services should now be ready!"
