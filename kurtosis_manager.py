#!/usr/bin/env python3
"""
Kurtosis Enclave Manager - Setup and teardown Ethereum testnets.

This script manages Kurtosis enclaves for running Geth and Besu nodes,
replacing the bash-based setup scripts with more maintainable Python.
"""

import argparse
import json
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Optional


DEFAULT_ENCLAVE = "my-testnet"
DEFAULT_PACKAGE = "github.com/ethpandaops/ethereum-package"
DEFAULT_ARGS_FILE = "minimal-pectra.yaml"


class KurtosisManager:
    """Manager for Kurtosis enclaves running Ethereum clients."""
    
    def __init__(
        self,
        enclave: str = DEFAULT_ENCLAVE,
        package: str = DEFAULT_PACKAGE,
        args_file: str = DEFAULT_ARGS_FILE
    ):
        self.enclave = enclave
        self.package = package
        self.args_file = Path(args_file)
    
    def _run_cmd(self, cmd: list[str], check: bool = True, capture: bool = False) -> subprocess.CompletedProcess:
        """Run a shell command."""
        if capture:
            return subprocess.run(cmd, capture_output=True, text=True, check=check)
        else:
            return subprocess.run(cmd, check=check)
    
    def enclave_exists(self) -> bool:
        """Check if the enclave already exists."""
        try:
            self._run_cmd(
                ["kurtosis", "enclave", "inspect", self.enclave],
                check=True,
                capture=True
            )
            return True
        except subprocess.CalledProcessError:
            return False
    
    def create_enclave(self) -> None:
        """Create a new Kurtosis enclave."""
        if not self.enclave_exists():
            print(f"Creating enclave '{self.enclave}'...")
            self._run_cmd(["kurtosis", "enclave", "add", "--name", self.enclave])
        else:
            print(f"Enclave '{self.enclave}' already exists")
    
    def prepare_args_file(self, besu_tag: Optional[str] = None) -> Path:
        """
        Prepare the args file, optionally replacing Besu docker tag.
        
        Returns:
            Path to the args file to use (may be a temporary file)
        """
        if not self.args_file.exists():
            raise FileNotFoundError(f"Args file not found: {self.args_file}")
        
        if besu_tag is None or besu_tag == "latest":
            return self.args_file
        
        # Read and replace Besu tag
        content = self.args_file.read_text()
        modified = content.replace(
            "hyperledger/besu:latest",
            f"hyperledger/besu:{besu_tag}"
        )
        
        # Write to temporary file in the same directory
        temp_file = self.args_file.parent / f".{self.args_file.name}.tag_{besu_tag}"
        temp_file.write_text(modified)
        print(f"Using temporary args file with Besu tag {besu_tag}: {temp_file}")
        
        return temp_file
    
    def parse_genesis_delay(self) -> int:
        """Parse genesis_delay from the args file."""
        if not self.args_file.exists():
            return 120  # Default
        
        content = self.args_file.read_text()
        match = re.search(r'^\s*genesis_delay\s*:\s*(\d+)', content, re.MULTILINE)
        if match:
            return int(match.group(1))
        return 120
    
    def run_package(self, args_file: Path) -> None:
        """Run the Kurtosis package to start the testnet."""
        print(f"Launching package {self.package} in enclave {self.enclave}")
        print(f"Using args file: {args_file}")
        
        self._run_cmd([
            "kurtosis", "run",
            "--enclave", self.enclave,
            self.package,
            "--args-file", str(args_file)
        ])
    
    def discover_cl_service(self) -> Optional[str]:
        """Discover a Consensus Layer (Teku) service."""
        candidates = ["cl-1-teku-geth", "cl-2-teku-besu", "cl-1-teku", "cl-2-teku"]
        
        for service in candidates:
            try:
                self._run_cmd(
                    ["kurtosis", "port", "print", self.enclave, service, "http"],
                    check=True,
                    capture=True
                )
                return service
            except subprocess.CalledProcessError:
                continue
        
        # Fallback: list services and find one with teku
        try:
            result = self._run_cmd(
                ["kurtosis", "service", "list", self.enclave],
                capture=True
            )
            for line in result.stdout.splitlines()[1:]:  # Skip header
                parts = line.split()
                if parts and "teku" in parts[0]:
                    return parts[0]
        except Exception:
            pass
        
        return None
    
    def discover_el_service(self, client_type: str) -> Optional[str]:
        """Discover an Execution Layer service (geth or besu)."""
        if client_type == "geth":
            candidates = ["el-1-geth-teku", "el-1-geth"]
            pattern = r"^el-.*geth"
        elif client_type == "besu":
            candidates = ["el-2-besu-teku", "el-2-besu"]
            pattern = r"^el-.*besu"
        else:
            raise ValueError(f"Unknown client type: {client_type}")
        
        for service in candidates:
            try:
                self._run_cmd(
                    ["kurtosis", "service", "inspect", self.enclave, service],
                    check=True,
                    capture=True
                )
                return service
            except subprocess.CalledProcessError:
                continue
        
        # Fallback: search service list
        try:
            result = self._run_cmd(
                ["kurtosis", "service", "list", self.enclave],
                capture=True
            )
            for line in result.stdout.splitlines()[1:]:
                parts = line.split()
                if parts and re.match(pattern, parts[0]):
                    return parts[0]
        except Exception:
            pass
        
        return None
    
    def get_port_url(self, service: str, port_name: str = "http") -> str:
        """Get the full URL for a service port."""
        url = None

        # Try kurtosis port print first
        try:
            result = self._run_cmd(
                ["kurtosis", "port", "print", self.enclave, service, port_name],
                capture=True
            )
            url = result.stdout.strip()
        except subprocess.CalledProcessError:
            pass

        # Fallback: construct from service inspect
        if not url:
            try:
                result = self._run_cmd(
                    ["kurtosis", "service", "inspect", "-o", "json", self.enclave, service],
                    capture=True
                )
                data = json.loads(result.stdout)
                port = data.get('public_ports', {}).get('rpc', {}).get('number')
                if not port:
                    port = data.get('public_ports', {}).get('http', {}).get('number')
                if port:
                    url = f"http://127.0.0.1:{port}"
            except Exception:
                pass

        if not url:
            raise RuntimeError(f"Could not get URL for {service}:{port_name}")

        # Ensure URL has http:// prefix
        if url and not url.startswith(('http://', 'https://')):
            url = f"http://{url}"

        return url

    def wait_for_beacon_genesis(self, cl_service: str) -> bool:
        """Wait for the Consensus Layer beacon genesis."""
        try:
            cl_url = self.get_port_url(cl_service, "http")
        except Exception:
            print(f"WARN: Could not find CL URL for {cl_service}")
            return False

        try:
            import requests
            response = requests.get(f"{cl_url}/eth/v1/beacon/genesis", timeout=10)
            data = response.json()
            genesis_time = int(data['data']['genesis_time'])
        except Exception as e:
            print(f"WARN: CL genesis endpoint unavailable: {e}")
            return False

        now = int(time.time())
        wait_seconds = genesis_time - now

        if wait_seconds > 0:
            print(f"Waiting ~{wait_seconds}s until beacon genesis ({genesis_time})...")
            time.sleep(wait_seconds)
        else:
            print(f"Beacon genesis already reached ({genesis_time})")

        return True

    def wait_for_el_ready(self, rpc_url: str, label: str, timeout: int = 120, verbose: bool = False) -> bool:
        """Wait for an Execution Layer node to be ready."""
        print(f"Waiting for {label} at {rpc_url} to respond...")

        import requests

        attempts = timeout // 2
        for attempt in range(1, attempts + 1):
            try:
                response = requests.post(
                    rpc_url,
                    json={
                        "jsonrpc": "2.0",
                        "id": 1,
                        "method": "eth_blockNumber",
                        "params": []
                    },
                    headers={"Content-Type": "application/json"},
                    timeout=5
                )

                if verbose:
                    print(f"  Attempt {attempt}/{attempts}: HTTP {response.status_code}")

                if response.status_code == 200:
                    result = response.json()
                    if verbose:
                        print(f"  Response: {result}")

                    if "result" in result:
                        block_number = result["result"]
                        print(f"{label} is responding (block: {block_number})")
                        return True
                    elif "error" in result:
                        if verbose:
                            print(f"  RPC error: {result['error']}")
                else:
                    if verbose:
                        print(f"  HTTP error: {response.status_code} - {response.text[:200]}")

            except requests.exceptions.Timeout:
                if verbose:
                    print(f"  Attempt {attempt}/{attempts}: Timeout after 5s")
            except requests.exceptions.ConnectionError as e:
                if verbose:
                    print(f"  Attempt {attempt}/{attempts}: Connection error - {str(e)[:100]}")
            except Exception as e:
                if verbose:
                    print(f"  Attempt {attempt}/{attempts}: Error - {type(e).__name__}: {str(e)[:100]}")

            if attempt < attempts:
                time.sleep(2)

        print(f"WARN: {label} did not respond within {timeout}s timeout")
        print(f"  URL: {rpc_url}")
        print(f"  This might indicate:")
        print(f"    - RPC port is not accessible")
        print(f"    - Node is still initializing")
        print(f"    - Network/firewall issue")
        return False

    def stop_enclave(self) -> None:
        """Stop and remove the enclave."""
        print(f"Stopping enclave '{self.enclave}'...")
        self._run_cmd(
            ["kurtosis", "enclave", "rm", "-f", self.enclave],
            check=False
        )
        print("Enclave stopped")

    def clean_all(self) -> None:
        """Complete cleanup of all Kurtosis resources."""
        print("Cleaning up all Kurtosis resources...")
        self._run_cmd(["kurtosis", "clean", "-a"], check=False)
        print("Cleanup complete")


def start_testnet(
    besu_tag: Optional[str] = None,
    enclave: str = DEFAULT_ENCLAVE,
    package: str = DEFAULT_PACKAGE,
    args_file: str = DEFAULT_ARGS_FILE,
    skip_wait: bool = False,
    verbose: bool = False
) -> dict:
    """
    Start a testnet with Geth and Besu nodes.

    Returns:
        Dictionary with service information and RPC URLs
    """
    manager = KurtosisManager(enclave, package, args_file)

    # Prepare args file with optional Besu tag
    temp_file = None
    if besu_tag:
        args_path = manager.prepare_args_file(besu_tag)
        if args_path != manager.args_file:
            temp_file = args_path
    else:
        args_path = manager.args_file

    try:
        # Create enclave if needed
        manager.create_enclave()

        # Run the package
        manager.run_package(args_path)

        # Wait for genesis
        cl_service = manager.discover_cl_service()
        if cl_service:
            print(f"Detected CL service: {cl_service}")
            if not manager.wait_for_beacon_genesis(cl_service):
                delay = manager.parse_genesis_delay()
                print(f"Falling back to genesis_delay: {delay}s")
                time.sleep(delay)
        else:
            delay = manager.parse_genesis_delay()
            print(f"Could not detect CL service, sleeping {delay}s...")
            time.sleep(delay)

        print("\nGenesis reached. Discovering EL services...")

        # Discover EL services
        geth_service = manager.discover_el_service("geth")
        besu_service = manager.discover_el_service("besu")

        result = {
            "enclave": enclave,
            "geth_service": geth_service,
            "besu_service": besu_service,
            "geth_rpc_url": None,
            "besu_rpc_url": None
        }

        if geth_service:
            try:
                geth_url = manager.get_port_url(geth_service, "rpc")
                result["geth_rpc_url"] = geth_url
                if verbose:
                    print(f"Discovered Geth service: {geth_service}")
                    print(f"  Raw port lookup returned URL: {geth_url}")
                print(f"Geth RPC: {geth_url} (service {geth_service})")
                if not skip_wait:
                    manager.wait_for_el_ready(geth_url, "Geth", verbose=verbose)
                else:
                    print("Skipping Geth readiness wait (--skip-wait enabled)")
            except Exception as e:
                print(f"WARN: Could not setup Geth: {e}")

        if besu_service:
            try:
                besu_url = manager.get_port_url(besu_service, "rpc")
                result["besu_rpc_url"] = besu_url
                if verbose:
                    print(f"Discovered Besu service: {besu_service}")
                    print(f"  Raw port lookup returned URL: {besu_url}")
                print(f"Besu RPC: {besu_url} (service {besu_service})")
                if not skip_wait:
                    manager.wait_for_el_ready(besu_url, "Besu", verbose=verbose)
                else:
                    print("Skipping Besu readiness wait (--skip-wait enabled)")
            except Exception as e:
                print(f"WARN: Could not setup Besu: {e}")

        print("\nServices should now be ready!")
        return result

    finally:
        # Cleanup temporary file
        if temp_file and temp_file.exists():
            temp_file.unlink()


def main():
    parser = argparse.ArgumentParser(description="Manage Kurtosis Ethereum testnet")
    subparsers = parser.add_subparsers(dest="command", help="Command to run")

    # Start command
    start_parser = subparsers.add_parser("start", help="Start the testnet")
    start_parser.add_argument(
        "--besu-tag",
        help="Besu Docker tag to use (default: latest)"
    )
    start_parser.add_argument(
        "--enclave",
        default=DEFAULT_ENCLAVE,
        help="Enclave name"
    )
    start_parser.add_argument(
        "--package",
        default=DEFAULT_PACKAGE,
        help="Kurtosis package to use"
    )
    start_parser.add_argument(
        "--args-file",
        default=DEFAULT_ARGS_FILE,
        help="Path to args YAML file"
    )
    start_parser.add_argument(
        "--output-json",
        help="Write service info to JSON file"
    )
    start_parser.add_argument(
        "--skip-wait",
        action="store_true",
        help="Skip waiting for EL nodes to be ready (useful if nodes are already running)"
    )
    start_parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Verbose output for debugging connection issues"
    )

    # Stop command
    stop_parser = subparsers.add_parser("stop", help="Stop the testnet")
    stop_parser.add_argument(
        "--enclave",
        default=DEFAULT_ENCLAVE,
        help="Enclave name"
    )

    # Clean command
    clean_parser = subparsers.add_parser("clean", help="Clean up all Kurtosis resources")

    # Info command
    info_parser = subparsers.add_parser("info", help="Get service information")
    info_parser.add_argument(
        "--enclave",
        default=DEFAULT_ENCLAVE,
        help="Enclave name"
    )

    args = parser.parse_args()

    if args.command == "start":
        result = start_testnet(
            besu_tag=args.besu_tag,
            enclave=args.enclave,
            package=args.package,
            args_file=args.args_file,
            skip_wait=args.skip_wait,
            verbose=args.verbose
        )

        if args.output_json:
            with open(args.output_json, 'w') as f:
                json.dump(result, f, indent=2)
            print(f"\nService info written to {args.output_json}")

    elif args.command == "stop":
        manager = KurtosisManager(args.enclave)
        manager.stop_enclave()

    elif args.command == "clean":
        manager = KurtosisManager()
        manager.clean_all()

    elif args.command == "info":
        manager = KurtosisManager(args.enclave)

        geth_service = manager.discover_el_service("geth")
        besu_service = manager.discover_el_service("besu")

        info = {
            "enclave": args.enclave,
            "geth_service": geth_service,
            "besu_service": besu_service,
        }

        if geth_service:
            try:
                info["geth_rpc_url"] = manager.get_port_url(geth_service, "rpc")
            except Exception:
                pass

        if besu_service:
            try:
                info["besu_rpc_url"] = manager.get_port_url(besu_service, "rpc")
            except Exception:
                pass

        print(json.dumps(info, indent=2))

    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()