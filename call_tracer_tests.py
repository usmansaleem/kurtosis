#!/usr/bin/env python3
"""
CallTracer Test Runner - Python replacement for bash-based testing.

This script runs Foundry scenarios against Besu and Geth nodes in a Kurtosis
environment and compares their debug_traceTransaction (callTracer) outputs.
"""

import argparse
import json
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import requests

from json_comparator import compare_call_traces, ComparisonResult


# Configuration
DEFAULT_PRIVATE_KEY = "04b9f63ecf84210c5366c66d68fa1f5da1fa4f634fad6dfc86178e4d79ff9e59"
DEFAULT_ENCLAVE = "my-testnet"

DEFAULT_SCENARIOS = [
    "SimpleTransfer",
    "CreateContract",
    "SimpleContractCall",
    "ContractCall",
    "NestedContractCall",
    "HelperRevert",
    "Delegatecall",
    "PrecompileBlake2F",
    "PrecompileBn128Add",
    "PrecompileBn128Mul",
    "PrecompileBn128Pairing",
    "PrecompileECRecover",
    "PrecompileIdentity",
    "PrecompileModExp",
    "PrecompileRIPEMD160",
    "PrecompileSHA256",
    "InsufficientBalance",
]


@dataclass
class TestResult:
    """Result of a single test scenario."""
    scenario: str
    passed: bool
    tx_hash: Optional[str] = None
    comparison: Optional[ComparisonResult] = None
    error_message: Optional[str] = None
    geth_response: Optional[dict] = None
    besu_response: Optional[dict] = None
    duration_seconds: float = 0.0


@dataclass
class TestSuite:
    """Collection of test results."""
    results: list[TestResult] = field(default_factory=list)
    geth_rpc_url: str = ""
    besu_rpc_url: str = ""
    
    @property
    def passed_count(self) -> int:
        return sum(1 for r in self.results if r.passed)
    
    @property
    def failed_count(self) -> int:
        return sum(1 for r in self.results if not r.passed)
    
    @property
    def total_count(self) -> int:
        return len(self.results)
    
    def summary(self) -> str:
        lines = [
            "=" * 60,
            "TEST SUITE SUMMARY",
            "=" * 60,
            f"Total:  {self.total_count}",
            f"Passed: {self.passed_count}",
            f"Failed: {self.failed_count}",
            "",
        ]
        
        if self.failed_count > 0:
            lines.append("Failed scenarios:")
            for result in self.results:
                if not result.passed:
                    lines.append(f"  ✗ {result.scenario}")
                    if result.error_message:
                        lines.append(f"    Error: {result.error_message}")
                    elif result.comparison:
                        lines.append(f"    Differences: {len(result.comparison.differences)}")
        
        lines.append("")
        lines.append("Passed scenarios:")
        for result in self.results:
            if result.passed:
                lines.append(f"  ✓ {result.scenario}")
        
        return '\n'.join(lines)


class KurtosisHelper:
    """Helper for interacting with Kurtosis enclaves."""
    
    def __init__(self, enclave: str = DEFAULT_ENCLAVE):
        self.enclave = enclave
    
    def get_service_rpc_port(self, service_name: str) -> int:
        """Get the RPC port for a service from Kurtosis."""
        try:
            result = subprocess.run(
                ["kurtosis", "service", "inspect", "-o", "json", self.enclave, service_name],
                capture_output=True,
                text=True,
                check=True
            )
            data = json.loads(result.stdout)
            return int(data['public_ports']['rpc']['number'])
        except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError) as e:
            raise RuntimeError(f"Failed to get RPC port for {service_name}: {e}")
    
    def get_rpc_url(self, service_name: str) -> str:
        """Get the full RPC URL for a service."""
        port = self.get_service_rpc_port(service_name)
        return f"http://127.0.0.1:{port}"
    
    def discover_services(self) -> tuple[str, str]:
        """Discover Geth and Besu service names."""
        # Default service names in ethpandaops/ethereum-package
        geth_service = "el-1-geth-teku"
        besu_service = "el-2-besu-teku"
        return geth_service, besu_service


class EthereumRPCClient:
    """Client for making Ethereum JSON-RPC calls."""
    
    def __init__(self, rpc_url: str, timeout: int = 30):
        self.rpc_url = rpc_url
        self.timeout = timeout
        self._request_id = 0
    
    def _next_id(self) -> int:
        self._request_id += 1
        return self._request_id
    
    def call(self, method: str, params: list) -> dict:
        """Make a JSON-RPC call."""
        payload = {
            "jsonrpc": "2.0",
            "id": self._next_id(),
            "method": method,
            "params": params
        }
        
        response = requests.post(
            self.rpc_url,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=self.timeout
        )
        response.raise_for_status()
        
        result = response.json()
        
        if "error" in result:
            raise RuntimeError(f"RPC error: {result['error']}")
        
        return result
    
    def get_transaction_by_hash(self, tx_hash: str) -> Optional[dict]:
        """Get transaction details by hash."""
        try:
            result = self.call("eth_getTransactionByHash", [tx_hash])
            return result.get("result")
        except Exception:
            return None
    
    def debug_trace_transaction(self, tx_hash: str, tracer: str = "callTracer") -> dict:
        """Call debug_traceTransaction with the specified tracer."""
        return self.call("debug_traceTransaction", [tx_hash, {"tracer": tracer}])
    
    def wait_for_transaction(self, tx_hash: str, max_attempts: int = 60, delay: float = 1.0) -> bool:
        """Wait for a transaction to be indexed."""
        for _ in range(max_attempts):
            tx = self.get_transaction_by_hash(tx_hash)
            if tx is not None:
                return True
            time.sleep(delay)
        return False


class ForgeRunner:
    """Runner for Foundry Forge scripts."""
    
    def __init__(self, contracts_dir: Path, private_key: str = DEFAULT_PRIVATE_KEY):
        self.contracts_dir = contracts_dir
        self.private_key = private_key
    
    def run_script(self, script_name: str, rpc_url: str) -> tuple[str, str]:
        """
        Run a Forge script and return the output.
        
        Returns:
            Tuple of (stdout, stderr)
        """
        script_path = f"script/{script_name}.s.sol"
        
        cmd = [
            "forge", "script", script_path,
            "--rpc-url", rpc_url,
            "--private-key", self.private_key,
            "--slow",
            "--json",
            "--broadcast"
        ]
        
        result = subprocess.run(
            cmd,
            cwd=self.contracts_dir,
            capture_output=True,
            text=True,
            timeout=120
        )
        
        return result.stdout, result.stderr
    
    def deploy_contracts(self, rpc_url: str) -> None:
        """Deploy all required contracts for testing."""
        print("Deploying contracts...")
        cmd = [
            "forge", "script", "script/DeployNestedContracts.s.sol",
            "--rpc-url", rpc_url,
            "--private-key", self.private_key,
            "--broadcast"
        ]
        
        subprocess.run(
            cmd,
            cwd=self.contracts_dir,
            check=True,
            capture_output=True,
            timeout=120
        )
        print("Contracts deployed successfully")


def extract_tx_hash(output: str) -> str:
    """
    Extract the last transaction hash from Forge output.
    
    Handles both JSON and plain text output formats.
    """
    # Try to parse as JSON first
    try:
        # Forge outputs multiple JSON objects, take the last valid one
        for line in reversed(output.strip().split('\n')):
            if line.strip().startswith('{'):
                try:
                    data = json.loads(line)
                    # Try various field names
                    for key in ['tx_hash', 'txHash', 'hash']:
                        if key in data:
                            tx_hash = data[key]
                            if re.match(r'^0x[0-9a-fA-F]{64}$', tx_hash):
                                return tx_hash
                except json.JSONDecodeError:
                    continue
    except Exception:
        pass
    
    # Fallback: grep for tx hash pattern
    matches = re.findall(r'0x[0-9a-fA-F]{64}', output)
    if matches:
        return matches[-1]  # Return the last match
    
    raise ValueError("Could not extract transaction hash from output")


def run_scenario(
    scenario: str,
    forge_runner: ForgeRunner,
    geth_client: EthereumRPCClient,
    besu_client: EthereumRPCClient,
    output_dir: Path,
    verbose: bool = False
) -> TestResult:
    """
    Run a single test scenario.
    
    1. Execute Forge script against Besu
    2. Wait for transaction on both clients
    3. Get callTracer results from both
    4. Compare outputs
    """
    start_time = time.time()
    
    print(f"\n{'='*60}")
    print(f"Running Scenario: {scenario}")
    print(f"{'='*60}")
    
    try:
        # Run Forge script against Besu
        print(f"\nExecuting Forge script on Besu...")
        stdout, stderr = forge_runner.run_script(scenario, besu_client.rpc_url)
        
        if verbose:
            print("Forge output:")
            print(stdout[:2000] if len(stdout) > 2000 else stdout)
        
        # Extract transaction hash
        tx_hash = extract_tx_hash(stdout)
        print(f"Transaction Hash: {tx_hash}")
        
        # Wait for transaction on both clients
        print("Waiting for transaction to be indexed...")
        
        if not besu_client.wait_for_transaction(tx_hash, max_attempts=60):
            raise RuntimeError("Transaction not indexed by Besu within timeout")
        
        if not geth_client.wait_for_transaction(tx_hash, max_attempts=60):
            raise RuntimeError("Transaction not indexed by Geth within timeout")
        
        print("Transaction indexed on both clients")
        
        # Get callTracer results
        print("Fetching callTracer results...")
        
        geth_response = geth_client.debug_trace_transaction(tx_hash)
        besu_response = besu_client.debug_trace_transaction(tx_hash)
        
        # Save raw responses
        geth_file = output_dir / f"{scenario}_geth.json"
        besu_file = output_dir / f"{scenario}_besu.json"
        
        with open(geth_file, 'w') as f:
            json.dump(geth_response, f, indent=2)
        
        with open(besu_file, 'w') as f:
            json.dump(besu_response, f, indent=2)
        
        print(f"Results saved to {output_dir}")
        
        # Quick gas comparison
        geth_gas = geth_response.get('result', {}).get('gasUsed', 'N/A')
        besu_gas = besu_response.get('result', {}).get('gasUsed', 'N/A')
        geth_type = geth_response.get('result', {}).get('type', 'N/A')
        besu_type = besu_response.get('result', {}).get('type', 'N/A')
        
        print(f"\nQuick Comparison:")
        print(f"  Gas Used - Geth: {geth_gas}, Besu: {besu_gas}")
        print(f"  Call Type - Geth: {geth_type}, Besu: {besu_type}")
        
        # Full comparison
        comparison = compare_call_traces(
            geth_response.get('result', {}),
            besu_response.get('result', {})
        )
        
        print(f"\n{comparison.summary()}")
        
        if not comparison.is_match and verbose:
            # Save detailed diff
            diff_file = output_dir / f"{scenario}_diff.txt"
            with open(diff_file, 'w') as f:
                f.write(comparison.detailed_report())
            print(f"Detailed diff saved to {diff_file}")
        
        duration = time.time() - start_time
        
        return TestResult(
            scenario=scenario,
            passed=comparison.is_match,
            tx_hash=tx_hash,
            comparison=comparison,
            geth_response=geth_response,
            besu_response=besu_response,
            duration_seconds=duration
        )
        
    except Exception as e:
        duration = time.time() - start_time
        print(f"\n✗ ERROR: {e}")
        return TestResult(
            scenario=scenario,
            passed=False,
            error_message=str(e),
            duration_seconds=duration
        )


def main():
    parser = argparse.ArgumentParser(
        description="Run callTracer compatibility tests between Geth and Besu"
    )
    parser.add_argument(
        "scenarios",
        nargs="*",
        default=DEFAULT_SCENARIOS,
        help="Scenarios to run (default: all)"
    )
    parser.add_argument(
        "--enclave",
        default=DEFAULT_ENCLAVE,
        help="Kurtosis enclave name"
    )
    parser.add_argument(
        "--private-key",
        default=DEFAULT_PRIVATE_KEY,
        help="Private key for transactions"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("output/scenarios"),
        help="Directory for output files"
    )
    parser.add_argument(
        "--geth-rpc-url",
        help="Override Geth RPC URL (skip Kurtosis discovery)"
    )
    parser.add_argument(
        "--besu-rpc-url",
        help="Override Besu RPC URL (skip Kurtosis discovery)"
    )
    parser.add_argument(
        "--skip-deploy",
        action="store_true",
        help="Skip contract deployment"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Verbose output"
    )
    parser.add_argument(
        "--save-report",
        type=Path,
        help="Save JSON report to file"
    )
    
    args = parser.parse_args()
    
    print("CallTracer Test Suite (Python)")
    print("=" * 60)
    
    # Setup output directory
    args.output_dir.mkdir(parents=True, exist_ok=True)
    
    # Get RPC URLs
    if args.geth_rpc_url and args.besu_rpc_url:
        geth_rpc_url = args.geth_rpc_url
        besu_rpc_url = args.besu_rpc_url
    else:
        print("Discovering RPC endpoints from Kurtosis...")
        kurtosis = KurtosisHelper(args.enclave)
        geth_service, besu_service = kurtosis.discover_services()
        geth_rpc_url = kurtosis.get_rpc_url(geth_service)
        besu_rpc_url = kurtosis.get_rpc_url(besu_service)
    
    print(f"Geth RPC: {geth_rpc_url}")
    print(f"Besu RPC: {besu_rpc_url}")
    
    # Initialize clients
    geth_client = EthereumRPCClient(geth_rpc_url)
    besu_client = EthereumRPCClient(besu_rpc_url)
    
    # Initialize Forge runner
    contracts_dir = Path(__file__).parent / "contracts"
    forge_runner = ForgeRunner(contracts_dir, args.private_key)
    
    # Deploy contracts if needed
    if not args.skip_deploy:
        print("\n" + "=" * 60)
        print("Deploying Contracts")
        print("=" * 60)
        forge_runner.deploy_contracts(geth_rpc_url)
    
    # Run scenarios
    suite = TestSuite(geth_rpc_url=geth_rpc_url, besu_rpc_url=besu_rpc_url)
    
    for scenario in args.scenarios:
        result = run_scenario(
            scenario,
            forge_runner,
            geth_client,
            besu_client,
            args.output_dir,
            args.verbose
        )
        suite.results.append(result)
    
    # Print summary
    print("\n" + suite.summary())
    
    # Save JSON report if requested
    if args.save_report:
        report = {
            "geth_rpc_url": suite.geth_rpc_url,
            "besu_rpc_url": suite.besu_rpc_url,
            "total": suite.total_count,
            "passed": suite.passed_count,
            "failed": suite.failed_count,
            "results": [
                {
                    "scenario": r.scenario,
                    "passed": r.passed,
                    "tx_hash": r.tx_hash,
                    "error": r.error_message,
                    "differences": len(r.comparison.differences) if r.comparison else 0,
                    "duration_seconds": r.duration_seconds
                }
                for r in suite.results
            ]
        }
        with open(args.save_report, 'w') as f:
            json.dump(report, f, indent=2)
        print(f"\nReport saved to {args.save_report}")
    
    # Exit with appropriate code
    if suite.failed_count > 0:
        print("\nFAILURE: Some tests failed")
        sys.exit(1)
    else:
        print("\nSUCCESS: All tests passed!")
        sys.exit(0)


if __name__ == "__main__":
    main()
