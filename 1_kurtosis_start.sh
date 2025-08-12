#!/bin/bash
set -euo pipefail

ENCLAVE="my-testnet"
ARTIFACT_NAME="besu_log4j"
LOCAL_LOG4J="./config"
PKG="github.com/ethpandaops/ethereum-package"
ARGS="./minimal-pectra.yaml"

echo "Starting kurtosis enclave ${ENCLAVE} with ethereum-package..."

# --- helpers ---
enclave_exists() {
  kurtosis enclave inspect "${ENCLAVE}" >/dev/null 2>&1
}

# Ensure enclave exists
if enclave_exists; then
  echo "Enclave '${ENCLAVE}' already exists."
else
  echo "Enclave '${ENCLAVE}' not found; creating..."
  kurtosis enclave add --name "${ENCLAVE}"
  echo "Uploading files artifact '${ARTIFACT_NAME}' from ${LOCAL_LOG4J}..."
  kurtosis files upload --name "${ARTIFACT_NAME}" "${ENCLAVE}" "${LOCAL_LOG4J}"
fi

# Run the package using your params (mounts the artifact by name)
echo "Launching package ${PKG} in enclave ${ENCLAVE}..."
kurtosis run --enclave "${ENCLAVE}" "${PKG}" --args-file "${ARGS}"

# Wait for genesis/init (simple sleep as before)
echo "Waiting for 90 seconds for Genesis Time to initialize..."
sleep 90

echo "Services should now be ready!"
