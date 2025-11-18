# CallTracer Testing Suite for Besu/Geth Compatibility

This repository contains tools for testing the compatibility of Besu's `debug_traceTransaction` (callTracer) output against Geth's implementation. It uses Kurtosis to spin up a local Ethereum testnet with both clients, runs various transaction scenarios, and performs detailed JSON comparison of the trace outputs.

## Prerequisites

- **Kurtosis** - [Installation Guide](https://docs.kurtosis.com/install)
- **Foundry** - [Installation Guide](https://getfoundry.sh/)
- **Python 3.10+** with requests library
- **Docker** for running the Ethereum clients
- Besu built locally with `./gradlew distDocker` (for custom Besu versions)

### Setup

#### Quick Setup (Recommended)

For automated setup, simply run:

```bash
# Linux/macOS
./setup.sh

# Windows
setup.bat
```

This script will:
- Verify all prerequisites are installed
- Initialize git submodules
- Create and activate a virtual environment
- Install Python dependencies

#### Manual Setup

If you prefer manual setup:

```bash
# Initialize git submodules (for forge-std)
git submodule update --init --recursive

# Create a Python virtual environment
python3 -m venv venv

# Activate the virtual environment
# On Linux/macOS:
source venv/bin/activate
# On Windows:
# venv\Scripts\activate

# Install Python dependencies in the virtual environment
pip install -r requirements.txt

# Verify Kurtosis is working
kurtosis version

# Verify Foundry is installed
forge --version
```

**Note:** Always activate the virtual environment before running the Python scripts:
```bash
# On Linux/macOS
source venv/bin/activate

# On Windows
venv\Scripts\activate
```

To deactivate the virtual environment when done:
```bash
deactivate
```

**Tip:** Add `venv/` to your `.gitignore` to avoid committing the virtual environment:
```bash
echo "venv/" >> .gitignore
```

## Quick Start

**Important:** Make sure to activate your virtual environment before running any commands:
```bash
source venv/bin/activate  # Linux/macOS
# or
venv\Scripts\activate     # Windows
```

### 1. Start the Testnet

```bash
# Start with latest Besu
python kurtosis_manager.py start

# Or start with a specific Besu tag
python kurtosis_manager.py start --besu-tag 25.8-develop-c64327f

# Save service info to JSON
python kurtosis_manager.py start --output-json services.json
```

### 2. Run Tests

```bash
# Run all test scenarios
python call_tracer_tests.py

# Run specific scenarios
python call_tracer_tests.py SimpleTransfer HelperRevert InsufficientBalance

# Verbose output with detailed diffs
python call_tracer_tests.py --verbose

# Save JSON report
python call_tracer_tests.py --save-report results.json

# Skip contract deployment (if already deployed)
python call_tracer_tests.py --skip-deploy
```

### 3. Analyze Results

```bash
# Batch analysis of all results
python trace_analyzer.py batch output/scenarios

# Compare specific scenario
python trace_analyzer.py compare output/scenarios/SimpleTransfer_geth.json output/scenarios/SimpleTransfer_besu.json

# Show call tree visualization
python trace_analyzer.py tree output/scenarios/NestedContractCall_geth.json

# Show JSON diff
python trace_analyzer.py diff output/scenarios/HelperRevert_geth.json output/scenarios/HelperRevert_besu.json --normalize
```

### 4. Stop the Testnet

```bash
python kurtosis_manager.py stop

# Or complete cleanup
python kurtosis_manager.py clean
```

## Python Scripts Overview

### `call_tracer_tests.py`
Main test runner that:
- Discovers Kurtosis service endpoints
- Runs Forge scripts to generate transactions
- Fetches callTracer results from both clients
- Performs detailed JSON comparison
- Generates test reports

```bash
# Full options
python call_tracer_tests.py --help

# Example with all options
python call_tracer_tests.py \
  --enclave my-testnet \
  --output-dir output/scenarios \
  --verbose \
  --save-report test_results.json \
  SimpleTransfer CreateContract
```

### `kurtosis_manager.py`
Manages Kurtosis enclave lifecycle:
- Start/stop testnets
- Dynamic Besu tag configuration
- Service discovery
- Genesis wait handling

```bash
# Commands
python kurtosis_manager.py start [OPTIONS]
python kurtosis_manager.py stop [OPTIONS]
python kurtosis_manager.py info [OPTIONS]
python kurtosis_manager.py clean
```

### `json_comparator.py`
Library for JSON comparison with:
- Semantic normalization of callTracer structures
- Deep recursive comparison
- Difference categorization
- Gas metric analysis

### `trace_analyzer.py`
Advanced analysis tool:
- Call tree visualization
- Gas discrepancy analysis
- Error message normalization
- Batch analysis of multiple scenarios

## Test Scenarios

The following scenarios are included by default:

| Scenario | Description |
|----------|-------------|
| `SimpleTransfer` | Basic ETH transfer |
| `CreateContract` | Contract creation |
| `SimpleContractCall` | Simple contract function call |
| `ContractCall` | Contract-to-contract call |
| `NestedContractCall` | Multiple nested calls |
| `HelperRevert` | Transaction with revert |
| `Delegatecall` | Delegatecall pattern |
| `PrecompileBlake2F` | Blake2F precompile |
| `PrecompileBn128Add` | BN128 addition |
| `PrecompileBn128Mul` | BN128 multiplication |
| `PrecompileBn128Pairing` | BN128 pairing check |
| `PrecompileECRecover` | Signature recovery |
| `PrecompileIdentity` | Identity precompile |
| `PrecompileModExp` | Modular exponentiation |
| `PrecompileRIPEMD160` | RIPEMD-160 hash |
| `PrecompileSHA256` | SHA-256 hash |
| `InsufficientBalance` | Insufficient balance error |

## Output Files

All output files are saved to `output/scenarios/`:

- `{scenario}_geth.json` - Raw Geth callTracer response
- `{scenario}_besu.json` - Raw Besu callTracer response
- `{scenario}_diff.txt` - Detailed diff (if differences found, with --verbose)

## JSON Comparison Details

The comparison normalizes callTracer output by:
1. Extracting relevant fields: `from`, `to`, `type`, `input`, `output`, `error`, `revertReason`, `gas`, `gasUsed`, `value`, `calls`
2. Removing null/empty values
3. Recursively normalizing nested calls
4. Performing deep comparison with path tracking

### Understanding Differences

The tool categorizes differences into:
- **missing_in_besu** - Field present in Geth but not Besu
- **missing_in_geth** - Field present in Besu but not Geth
- **value_mismatch** - Same field with different values
- **type_mismatch** - Same field with different types

## Advanced Usage

### Manual RPC URL Override

```bash
# Use specific RPC URLs instead of Kurtosis discovery
python call_tracer_tests.py \
  --geth-rpc-url http://localhost:8545 \
  --besu-rpc-url http://localhost:8546
```

### Error Message Normalization

The trace analyzer includes error message normalization for semantic comparison:

```python
# Example normalizations
"invalid input length: expected 128 bytes" -> "invalid input length"
"Point not on curve" -> "point not on curve"
"execution reverted" -> "execution reverted"
```

### Gas Analysis

```bash
# Detailed gas discrepancy report
python trace_analyzer.py compare scenario_geth.json scenario_besu.json --verbose
```

Output includes:
- Per-call gas values
- Gas differences with path location
- Call type distribution

## Extending the Test Suite

### Adding New Scenarios

1. Create a new Forge script in `contracts/script/YourScenario.s.sol`
2. Add the scenario name to the test list:

```bash
python call_tracer_tests.py YourScenario
```

Or modify `DEFAULT_SCENARIOS` in `call_tracer_tests.py`.

### Custom Comparisons

```python
from json_comparator import compare_call_traces
import json

with open('geth.json') as f:
    geth = json.load(f)
with open('besu.json') as f:
    besu = json.load(f)

result = compare_call_traces(geth['result'], besu['result'])
print(result.summary())
print(result.detailed_report())
```

## Troubleshooting

### Virtual Environment Issues

If you encounter `ModuleNotFoundError` or import errors:

```bash
# Verify virtual environment is activated (you should see (venv) in your prompt)
which python  # Should point to venv/bin/python

# If not activated, activate it:
source venv/bin/activate  # Linux/macOS
# or
venv\Scripts\activate     # Windows

# Reinstall dependencies if needed
pip install -r requirements.txt

# Verify requests is installed
pip list | grep requests
```

### Common Issues

1. **Transaction not indexed**: Increase wait timeout or check client sync status
2. **Kurtosis service not found**: Verify enclave is running with `kurtosis enclave inspect my-testnet`
3. **Forge script fails**: Check contract compilation with `forge build`
4. **RPC connection refused**: Ensure Kurtosis ports are mapped correctly

### Debugging

```bash
# Check Kurtosis services
kurtosis enclave inspect my-testnet

# View Besu logs
kurtosis service logs my-testnet el-2-besu-teku

# Check custom Besu logs (inside container)
kurtosis service shell my-testnet el-2-besu-teku
cat /tmp/calltracer.log
```

## Useful Kurtosis Commands

```bash
# List all services in enclave
kurtosis service list my-testnet

# Get service details
kurtosis service inspect my-testnet el-2-besu-teku

# View logs
kurtosis service logs my-testnet el-2-besu-teku

# Open shell in container
kurtosis service shell my-testnet el-2-besu-teku

# Complete teardown
kurtosis clean -a
```

## Contributing

When adding new test scenarios or improving the comparison logic:

1. Ensure Forge scripts follow existing patterns
2. Add comprehensive error handling
3. Update this README with new features
4. Consider edge cases (gas limits, errors, precompiles)
