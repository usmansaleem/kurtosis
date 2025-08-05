# Ethereum devnet using Kurtosis
https://github.com/ethpandaops/ethereum-package

## Prereq
- Kurtosis is installed. https://docs.kurtosis.com/install
- Foundary is installed. https://getfoundry.sh/
- `git submodule update --init --recursive` has been executed on the checked out repo.
- Besu is built locally with `./gradlew -Prelease.releaseVersion=develop distDocker`
- Change docker tags in `minimal-pectra.yaml` according to your requirements.

## Start devnet using Kurtosis

```shell
./1_kurtosis_start.sh
```
- Wait for genesis to be created. Takes about a minute.
- The Genesis time can be checked at `dora` at `http://127.0.0.1:36000`. The dora address is reported when kurtosis 
command is finished.

### Test
The following script will deploy various contracts and run testing scenarios. See `output/scenarios` for the results.

```shell
./2_run_call_tracer_tests.sh
```

### Tear down
```shell
./3_kurtosis_stop.sh
```

## Useful kurtosis commands
```shell
# Report all running services
kurtosis enclave inspect my-testnet

# Read logs of a specific service
kurtosis service logs my-testnet el-2-besu-teku  

# Tear down
kurtosis enclave rm -f my-testnet

# Or, Complete teardown of all services and cleanup the enclave
kurtosis clean -a

# Stop the kurtosis engine
kurtosis engine stop
```