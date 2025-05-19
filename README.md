# Ethereum devnet using Kurtosis

https://github.com/ethpandaops/ethereum-package

## Start devnet using Kurtosis

```shell
kurtosis run --enclave my-testnet github.com/ethpandaops/ethereum-package --args-file ./minimal-pectra.yaml
```

- Wait for genesis to be created. Takes about a minute.

### Deploy contracts

```shell
./deploy.sh
```

### Call contract methods

See Contract # 3 address from deploy.sh output. and update script if required.

```shell
./nested_call_tx.sh
```

### Call debug trace method on transaction

Copy/Paste transactionHash from nested_call_tx.sh output.

```shell
./run_debug_trace_tx.sh <tx_hash>
```

## Cleaning up
```shell
kurtosis clean -a
```