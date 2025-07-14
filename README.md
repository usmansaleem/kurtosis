# Ethereum devnet using Kurtosis
https://github.com/ethpandaops/ethereum-package

## Prereq
- Besu is built locally with `./gradlew -Prelease.releaseVersion=develop distDocker`
- Change docker tags in `minimal-pectra.yaml` according to your requirements.

## Start devnet using Kurtosis

```shell
kurtosis run --enclave my-testnet github.com/ethpandaops/ethereum-package --args-file ./minimal-pectra.yaml
```

- Wait for genesis to be created. Takes about a minute.
- The Genesis time can be checked at `dora` at `http://127.0.0.1:36000`. The dora address is reported when kurtosis 
command is finished.

### Deploy contracts

```shell
./deploy.sh
```

Note the contract addresses printed in the output. They will be used in the next steps.

```shell
== Logs ==
  Contract1 deployed at: 0xc190dD4f971bf07A778dEB48C4Dc45dd64582f44
  Contract2 deployed at: 0x9d86dbCcdf537F0a0BAF43160d2Ef1570d84E358
  Contract3 deployed at: 0xC3536F63aB92bc7902dB5D57926c80f933121Bca
```

### Call contract methods

See Contract # 3 address from deploy.sh output. If address is not `0xC3536F63aB92bc7902dB5D57926c80f933121Bca`, change 
it in the script. Most likely, it will be the same.

```shell
./call_nested_tx.sh
```

### Call debug trace method on transaction

Copy/Paste transactionHash from nested_call_tx.sh output. It should look like this:
```shell
status               1 (success)
transactionHash      0x65e53f014cbd3e55921fc0825c774ca63b48cc8300eba993b8662fe1b0fa16ef
transactionIndex     57
type                 2
```
The transaction hash will always be different, so make sure to copy the one from the output.
```shell
./run_debug_trace_tx.sh 0x65e53f014cbd3e55921fc0825c774ca63b48cc8300eba993b8662fe1b0fa16ef
```

## Cleaning up
```shell
kurtosis clean -a
```