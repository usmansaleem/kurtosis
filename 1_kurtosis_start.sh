#!/bin/bash

# Script to run kurtosis with ethereum-package and wait for initialization

echo "Starting kurtosis with ethereum-package..."
kurtosis run --enclave my-testnet github.com/ethpandaops/ethereum-package --args-file ./minimal-pectra.yaml

echo "Waiting for 90 seconds for Genesis Time to initialize..."
sleep 90

echo "Services should now be ready!"
