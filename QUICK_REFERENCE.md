# Quick Reference Guide

## Initial Setup

```bash
# Automated setup (recommended)
./setup.sh              # Linux/macOS
setup.bat               # Windows

# Manual setup
python3 -m venv venv
source venv/bin/activate   # Linux/macOS
pip install -r requirements.txt
```

## Activate Virtual Environment

**Always run this before using any Python scripts:**

```bash
# Linux/macOS
source venv/bin/activate

# Windows CMD
venv\Scripts\activate

# Windows PowerShell
venv\Scripts\Activate.ps1
```

You should see `(venv)` in your prompt when activated.

## Common Workflows

### Full Test Run

```bash
# 1. Activate venv
source venv/bin/activate

# 2. Start testnet
python kurtosis_manager.py start

# 3. Run all tests
python call_tracer_tests.py --verbose

# 4. Analyze results
python trace_analyzer.py batch output/scenarios

# 5. Stop testnet
python kurtosis_manager.py stop
```

### Custom Besu Version

```bash
python kurtosis_manager.py start --besu-tag 25.8-develop-c64327f
python call_tracer_tests.py
python kurtosis_manager.py stop
```

### Specific Test Scenarios

```bash
python call_tracer_tests.py SimpleTransfer HelperRevert InsufficientBalance
```

### With Detailed Reports

```bash
python call_tracer_tests.py --verbose --save-report results.json
```

## Analysis Commands

### Compare Two Traces

```bash
python trace_analyzer.py compare \
  output/scenarios/HelperRevert_geth.json \
  output/scenarios/HelperRevert_besu.json
```

### View Call Tree

```bash
python trace_analyzer.py tree output/scenarios/NestedContractCall_geth.json
```

### Batch Analysis

```bash
# Summary
python trace_analyzer.py batch output/scenarios

# JSON output
python trace_analyzer.py batch output/scenarios --json
```

### Show JSON Diff

```bash
python trace_analyzer.py diff \
  output/scenarios/ContractCall_geth.json \
  output/scenarios/ContractCall_besu.json \
  --normalize
```

## Kurtosis Management

### Get Service Info

```bash
python kurtosis_manager.py info
python kurtosis_manager.py info --output-json services.json
```

### Manual RPC URLs

```bash
python call_tracer_tests.py \
  --geth-rpc-url http://localhost:8545 \
  --besu-rpc-url http://localhost:8546
```

### Complete Cleanup

```bash
python kurtosis_manager.py clean
```

## Kurtosis Direct Commands

```bash
# View all services
kurtosis enclave inspect my-testnet

# Service logs
kurtosis service logs my-testnet el-2-besu-teku

# Shell into container
kurtosis service shell my-testnet el-2-besu-teku

# View custom Besu logs (inside container)
cat /tmp/calltracer.log

# Remove enclave
kurtosis enclave rm -f my-testnet
```

## Troubleshooting

### Check if venv is active

```bash
which python        # Should point to venv/bin/python
pip list | grep requests   # Should show requests
```

### Reinstall dependencies

```bash
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### Start fresh

```bash
deactivate
rm -rf venv
./setup.sh
```

### Transaction not found

```bash
# Wait longer or check client sync
python call_tracer_tests.py --verbose
```

## File Locations

- **Test outputs**: `output/scenarios/`
- **Raw Geth traces**: `output/scenarios/*_geth.json`
- **Raw Besu traces**: `output/scenarios/*_besu.json`
- **Diff reports**: `output/scenarios/*_diff.txt`
- **Test reports**: Specified with `--save-report`

## Environment Variables

```bash
# Override enclave name
export ENCLAVE=my-custom-testnet

# Override Besu tag
export TAG=25.8-develop-c64327f
```

## Exit/Cleanup

```bash
# Deactivate virtual environment
deactivate

# Stop testnet
python kurtosis_manager.py stop

# Complete cleanup
python kurtosis_manager.py clean
```

## Getting Help

```bash
# Script help
python call_tracer_tests.py --help
python kurtosis_manager.py --help
python trace_analyzer.py --help

# See README.md for detailed documentation
# See VENV_SETUP.md for virtual environment details
```
