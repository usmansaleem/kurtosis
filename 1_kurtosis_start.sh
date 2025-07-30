#!/bin/bash

# Script to run kurtosis with ethereum-package and wait for initialization

echo "Starting kurtosis with ethereum-package..."
kurtosis run --enclave my-testnet github.com/ethpandaops/ethereum-package --args-file ./minimal-pectra.yaml

echo "Waiting for 130 seconds for services to initialize..."
sleep 130

echo "Services should now be ready!"
