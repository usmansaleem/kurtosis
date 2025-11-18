#!/usr/bin/env python3
"""
RPC Diagnostic Tool - Test connectivity and RPC functionality.

This script helps diagnose issues with Geth/Besu RPC endpoints.
"""

import argparse
import json
import sys
import time

import requests


def test_basic_connectivity(url: str) -> dict:
    """Test basic HTTP connectivity to the RPC endpoint."""
    result = {
        "test": "Basic Connectivity",
        "url": url,
        "success": False,
        "details": {}
    }

    try:
        response = requests.get(url, timeout=5)
        result["details"]["status_code"] = response.status_code
        result["details"]["accessible"] = True
        result["success"] = True

        # Some RPC endpoints return 405 (Method Not Allowed) for GET requests
        # This is actually a good sign - the endpoint exists
        if response.status_code in [200, 405]:
            result["details"]["note"] = "Endpoint is accessible"
        else:
            result["details"]["note"] = f"Unexpected status code: {response.status_code}"

    except requests.exceptions.Timeout:
        result["details"]["error"] = "Connection timeout after 5 seconds"
    except requests.exceptions.ConnectionError as e:
        result["details"]["error"] = f"Connection error: {str(e)}"
    except Exception as e:
        result["details"]["error"] = f"Unexpected error: {str(e)}"

    return result


def test_rpc_method(url: str, method: str, params: list = None) -> dict:
    """Test a specific JSON-RPC method."""
    if params is None:
        params = []

    result = {
        "test": f"RPC Method: {method}",
        "url": url,
        "success": False,
        "details": {}
    }

    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params
    }

    try:
        response = requests.post(
            url,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )

        result["details"]["http_status"] = response.status_code

        if response.status_code == 200:
            data = response.json()
            result["details"]["response"] = data

            if "result" in data:
                result["success"] = True
                result["details"]["result"] = data["result"]
                result["details"]["note"] = "Method call successful"
            elif "error" in data:
                result["details"]["rpc_error"] = data["error"]
                result["details"]["note"] = "RPC returned an error"
            else:
                result["details"]["note"] = "Unexpected response format"
        else:
            result["details"]["http_error"] = response.text[:500]

    except requests.exceptions.Timeout:
        result["details"]["error"] = "Request timeout after 10 seconds"
    except requests.exceptions.ConnectionError as e:
        result["details"]["error"] = f"Connection error: {str(e)}"
    except json.JSONDecodeError:
        result["details"]["error"] = "Invalid JSON response"
        result["details"]["raw_response"] = response.text[:500]
    except Exception as e:
        result["details"]["error"] = f"Unexpected error: {type(e).__name__}: {str(e)}"

    return result


def test_eth_methods(url: str) -> list:
    """Test common Ethereum JSON-RPC methods."""
    methods = [
        ("eth_blockNumber", []),
        ("eth_chainId", []),
        ("eth_syncing", []),
        ("net_version", []),
        ("web3_clientVersion", []),
    ]

    results = []
    for method, params in methods:
        result = test_rpc_method(url, method, params)
        results.append(result)
        time.sleep(0.1)  # Small delay between requests

    return results


def test_debug_methods(url: str) -> list:
    """Test debug_* methods (may not be available on all nodes)."""
    # We can't test debug_traceTransaction without a real tx hash
    # But we can try methods that might work without parameters
    methods = [
        ("debug_getRawHeader", ["latest"]),
    ]

    results = []
    for method, params in methods:
        result = test_rpc_method(url, method, params)
        results.append(result)

    return results


def print_result(result: dict) -> None:
    """Print a test result in a readable format."""
    status = "✓ PASS" if result["success"] else "✗ FAIL"
    print(f"\n{status}: {result['test']}")
    print(f"URL: {result['url']}")

    for key, value in result["details"].items():
        if key == "response":
            continue  # Skip full response to avoid clutter
        if isinstance(value, dict):
            print(f"  {key}:")
            for k, v in value.items():
                print(f"    {k}: {v}")
        else:
            print(f"  {key}: {value}")


def run_diagnostics(url: str, include_debug: bool = False, verbose: bool = False) -> dict:
    """Run full diagnostic suite."""
    print(f"Running RPC diagnostics for: {url}")
    print("=" * 60)

    all_results = []

    # Test 1: Basic connectivity
    print("\n1. Testing basic connectivity...")
    result = test_basic_connectivity(url)
    all_results.append(result)
    if verbose or not result["success"]:
        print_result(result)
    elif result["success"]:
        print("  ✓ Endpoint is accessible")

    # Test 2: Standard Ethereum methods
    print("\n2. Testing standard Ethereum RPC methods...")
    eth_results = test_eth_methods(url)
    all_results.extend(eth_results)

    passed = sum(1 for r in eth_results if r["success"])
    print(f"  {passed}/{len(eth_results)} methods successful")

    if verbose:
        for result in eth_results:
            print_result(result)
    else:
        for result in eth_results:
            status = "✓" if result["success"] else "✗"
            method = result["test"].replace("RPC Method: ", "")
            if result["success"] and "result" in result["details"]:
                res = result["details"]["result"]
                print(f"  {status} {method}: {res}")
            else:
                print(f"  {status} {method}")
                if not result["success"] and "error" in result["details"]:
                    print(f"      Error: {result['details']['error']}")

    # Test 3: Debug methods (optional)
    if include_debug:
        print("\n3. Testing debug RPC methods...")
        debug_results = test_debug_methods(url)
        all_results.extend(debug_results)

        for result in debug_results:
            print_result(result)

    # Summary
    total = len(all_results)
    passed = sum(1 for r in all_results if r["success"])

    print("\n" + "=" * 60)
    print(f"SUMMARY: {passed}/{total} tests passed")

    if passed == total:
        print("✓ All tests passed - RPC endpoint is working correctly")
    elif passed == 0:
        print("✗ All tests failed - RPC endpoint may not be accessible")
    else:
        print("⚠ Some tests failed - endpoint is partially accessible")

    return {
        "url": url,
        "total_tests": total,
        "passed": passed,
        "failed": total - passed,
        "results": all_results
    }


def main():
    parser = argparse.ArgumentParser(
        description="Diagnose RPC connectivity and functionality issues"
    )
    parser.add_argument(
        "url",
        nargs="?",
        help="RPC URL to test (e.g., http://localhost:8545)"
    )
    parser.add_argument(
        "--geth",
        action="store_true",
        help="Test default Geth URL (http://localhost:8545)"
    )
    parser.add_argument(
        "--besu",
        action="store_true",
        help="Test default Besu URL (http://localhost:8546)"
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Include debug_* method tests"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Verbose output"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON"
    )

    args = parser.parse_args()

    # Determine URL to test
    urls = []
    if args.url:
        urls.append(args.url)
    if args.geth:
        urls.append("http://localhost:8545")
    if args.besu:
        urls.append("http://localhost:8546")

    if not urls:
        print("Error: Please provide a URL to test")
        print("\nExamples:")
        print("  python rpc_diagnostics.py http://localhost:8545")
        print("  python rpc_diagnostics.py --geth")
        print("  python rpc_diagnostics.py --besu")
        print("  python rpc_diagnostics.py http://127.0.0.1:54321 --verbose")
        sys.exit(1)

    # Run diagnostics for each URL
    all_summaries = []
    for url in urls:
        summary = run_diagnostics(url, include_debug=args.debug, verbose=args.verbose)
        all_summaries.append(summary)

        if len(urls) > 1:
            print("\n" + "=" * 60 + "\n")

    # Output JSON if requested
    if args.json:
        print("\n" + "=" * 60)
        print("JSON OUTPUT:")
        print(json.dumps(all_summaries, indent=2))

    # Exit code based on results
    all_passed = all(s["passed"] == s["total_tests"] for s in all_summaries)
    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()