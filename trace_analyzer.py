#!/usr/bin/env python3
"""
CallTracer Output Analyzer - Deep inspection and debugging tool.

This tool provides detailed analysis of callTracer outputs, including:
- Gas calculation breakdowns
- Error message normalization and comparison
- Call tree visualization
- Specific discrepancy identification
"""

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional

from json_comparator import (
    compare_call_traces,
    normalize_call_trace,
    extract_gas_summary,
    format_json_diff
)


# Error message normalization patterns
# Maps Besu error patterns to normalized forms for comparison
ERROR_NORMALIZATIONS = {
    # Precompile errors
    r"invalid input length.*expected (\d+)": "invalid input length",
    r"input length.*must be.*(\d+)": "invalid input length",
    r"Point not on curve": "point not on curve",
    r"invalid point encoding": "point not on curve",
    # Gas/resource errors
    r"out of gas": "out of gas",
    r"gas.*insufficient": "out of gas",
    # Call errors
    r"execution reverted": "execution reverted",
    r"revert": "execution reverted",
}


@dataclass
class CallNode:
    """Represents a node in the call tree."""
    call_type: str
    from_addr: str
    to_addr: str
    gas: str
    gas_used: str
    value: str
    input_data: str
    output_data: str
    error: Optional[str] = None
    revert_reason: Optional[str] = None
    children: list["CallNode"] = None
    depth: int = 0
    
    def __post_init__(self):
        if self.children is None:
            self.children = []
    
    @classmethod
    def from_trace(cls, trace: dict, depth: int = 0) -> "CallNode":
        """Create a CallNode from a trace dictionary."""
        children = []
        if "calls" in trace:
            children = [cls.from_trace(child, depth + 1) for child in trace["calls"]]
        
        return cls(
            call_type=trace.get("type", "UNKNOWN"),
            from_addr=trace.get("from", ""),
            to_addr=trace.get("to", ""),
            gas=trace.get("gas", "0x0"),
            gas_used=trace.get("gasUsed", "0x0"),
            value=trace.get("value", "0x0"),
            input_data=trace.get("input", "0x"),
            output_data=trace.get("output", "0x"),
            error=trace.get("error"),
            revert_reason=trace.get("revertReason"),
            children=children,
            depth=depth
        )
    
    def tree_repr(self, indent: str = "  ") -> str:
        """Generate a tree representation of the call."""
        prefix = indent * self.depth
        
        # Format addresses (truncate for readability)
        from_short = self.from_addr[:10] + "..." if len(self.from_addr) > 12 else self.from_addr
        to_short = self.to_addr[:10] + "..." if len(self.to_addr) > 12 else self.to_addr
        
        # Parse hex gas values
        gas_int = int(self.gas, 16) if self.gas.startswith("0x") else int(self.gas)
        gas_used_int = int(self.gas_used, 16) if self.gas_used.startswith("0x") else int(self.gas_used)
        
        lines = [
            f"{prefix}├─ {self.call_type} {from_short} → {to_short}",
            f"{prefix}│  Gas: {gas_int} ({self.gas}), Used: {gas_used_int} ({self.gas_used})"
        ]
        
        if self.error:
            lines.append(f"{prefix}│  ⚠️  Error: {self.error}")
        
        if self.revert_reason:
            lines.append(f"{prefix}│  Revert: {self.revert_reason}")
        
        for child in self.children:
            lines.append(child.tree_repr(indent))
        
        return "\n".join(lines)


def normalize_error_message(error: str) -> str:
    """Normalize an error message for cross-client comparison."""
    if not error:
        return ""
    
    error_lower = error.lower()
    
    for pattern, normalized in ERROR_NORMALIZATIONS.items():
        if re.search(pattern, error_lower):
            return normalized
    
    return error_lower


def compare_error_messages(geth_error: Optional[str], besu_error: Optional[str]) -> dict:
    """Compare error messages between Geth and Besu."""
    result = {
        "geth_error": geth_error,
        "besu_error": besu_error,
        "exact_match": geth_error == besu_error,
        "semantic_match": False,
        "geth_normalized": None,
        "besu_normalized": None
    }
    
    if geth_error:
        result["geth_normalized"] = normalize_error_message(geth_error)
    if besu_error:
        result["besu_normalized"] = normalize_error_message(besu_error)
    
    result["semantic_match"] = result["geth_normalized"] == result["besu_normalized"]
    
    return result


def analyze_gas_discrepancies(geth_trace: dict, besu_trace: dict, path: str = "root") -> list[dict]:
    """Analyze gas-related discrepancies in detail."""
    discrepancies = []
    
    geth_gas = geth_trace.get("gas", "0x0")
    besu_gas = besu_trace.get("gas", "0x0")
    geth_used = geth_trace.get("gasUsed", "0x0")
    besu_used = besu_trace.get("gasUsed", "0x0")
    
    # Convert to integers for comparison
    geth_gas_int = int(geth_gas, 16) if geth_gas.startswith("0x") else int(geth_gas)
    besu_gas_int = int(besu_gas, 16) if besu_gas.startswith("0x") else int(besu_gas)
    geth_used_int = int(geth_used, 16) if geth_used.startswith("0x") else int(geth_used)
    besu_used_int = int(besu_used, 16) if besu_used.startswith("0x") else int(besu_used)
    
    if geth_gas_int != besu_gas_int:
        discrepancies.append({
            "path": path,
            "field": "gas",
            "geth": geth_gas_int,
            "besu": besu_gas_int,
            "difference": besu_gas_int - geth_gas_int
        })
    
    if geth_used_int != besu_used_int:
        discrepancies.append({
            "path": path,
            "field": "gasUsed",
            "geth": geth_used_int,
            "besu": besu_used_int,
            "difference": besu_used_int - geth_used_int
        })
    
    # Recursively check nested calls
    geth_calls = geth_trace.get("calls", [])
    besu_calls = besu_trace.get("calls", [])
    
    min_len = min(len(geth_calls), len(besu_calls))
    for i in range(min_len):
        nested = analyze_gas_discrepancies(
            geth_calls[i],
            besu_calls[i],
            f"{path}.calls[{i}]"
        )
        discrepancies.extend(nested)
    
    return discrepancies


def count_calls(trace: dict) -> dict:
    """Count different types of calls in a trace."""
    counts = {}
    
    call_type = trace.get("type", "UNKNOWN")
    counts[call_type] = counts.get(call_type, 0) + 1
    
    for child in trace.get("calls", []):
        child_counts = count_calls(child)
        for k, v in child_counts.items():
            counts[k] = counts.get(k, 0) + v
    
    return counts


def calculate_total_gas(trace: dict) -> int:
    """Calculate total gas used across all calls."""
    gas_used = trace.get("gasUsed", "0x0")
    total = int(gas_used, 16) if gas_used.startswith("0x") else int(gas_used)
    
    # Note: Nested call gas is typically included in parent, so we don't add
    # This is just for verification
    return total


def analyze_trace_file(file_path: Path) -> dict:
    """Analyze a single trace file."""
    with open(file_path) as f:
        data = json.load(f)
    
    trace = data.get("result", {})
    
    return {
        "file": str(file_path),
        "call_tree": CallNode.from_trace(trace),
        "call_counts": count_calls(trace),
        "total_gas_used": calculate_total_gas(trace),
        "has_error": "error" in trace,
        "has_revert": "revertReason" in trace,
        "normalized": normalize_call_trace(trace)
    }


def compare_trace_files(geth_file: Path, besu_file: Path) -> dict:
    """Compare two trace files in detail."""
    with open(geth_file) as f:
        geth_data = json.load(f)
    with open(besu_file) as f:
        besu_data = json.load(f)
    
    geth_trace = geth_data.get("result", {})
    besu_trace = besu_data.get("result", {})
    
    # Basic comparison
    comparison = compare_call_traces(geth_trace, besu_trace)
    
    # Detailed analysis
    gas_discrepancies = analyze_gas_discrepancies(geth_trace, besu_trace)
    
    error_comparison = compare_error_messages(
        geth_trace.get("error"),
        besu_trace.get("error")
    )
    
    return {
        "geth_file": str(geth_file),
        "besu_file": str(besu_file),
        "match": comparison.is_match,
        "total_differences": len(comparison.differences),
        "comparison": comparison,
        "gas_discrepancies": gas_discrepancies,
        "error_comparison": error_comparison,
        "geth_call_counts": count_calls(geth_trace),
        "besu_call_counts": count_calls(besu_trace),
        "geth_tree": CallNode.from_trace(geth_trace),
        "besu_tree": CallNode.from_trace(besu_trace)
    }


def print_analysis(analysis: dict, verbose: bool = False) -> None:
    """Print analysis results in a readable format."""
    print("=" * 70)
    print("TRACE ANALYSIS REPORT")
    print("=" * 70)
    
    if "geth_file" in analysis:
        # Comparison analysis
        print(f"\nGeth File: {analysis['geth_file']}")
        print(f"Besu File: {analysis['besu_file']}")
        print(f"\nMatch: {'✓ YES' if analysis['match'] else '✗ NO'}")
        print(f"Total Differences: {analysis['total_differences']}")
        
        print("\n--- Call Type Counts ---")
        print(f"Geth: {analysis['geth_call_counts']}")
        print(f"Besu: {analysis['besu_call_counts']}")
        
        if analysis['gas_discrepancies']:
            print("\n--- Gas Discrepancies ---")
            for disc in analysis['gas_discrepancies']:
                print(f"  {disc['path']}.{disc['field']}: "
                      f"Geth={disc['geth']}, Besu={disc['besu']} "
                      f"(diff: {disc['difference']:+d})")
        
        if not analysis['error_comparison']['exact_match']:
            print("\n--- Error Message Comparison ---")
            err_comp = analysis['error_comparison']
            print(f"  Geth Error: {err_comp['geth_error']}")
            print(f"  Besu Error: {err_comp['besu_error']}")
            print(f"  Normalized Geth: {err_comp['geth_normalized']}")
            print(f"  Normalized Besu: {err_comp['besu_normalized']}")
            print(f"  Semantic Match: {'✓' if err_comp['semantic_match'] else '✗'}")
        
        if verbose:
            print("\n--- Geth Call Tree ---")
            print(analysis['geth_tree'].tree_repr())
            
            print("\n--- Besu Call Tree ---")
            print(analysis['besu_tree'].tree_repr())
            
            if not analysis['match']:
                print("\n--- Detailed Differences ---")
                print(analysis['comparison'].detailed_report())
    else:
        # Single file analysis
        print(f"\nFile: {analysis['file']}")
        print(f"Call Counts: {analysis['call_counts']}")
        print(f"Total Gas Used: {analysis['total_gas_used']}")
        print(f"Has Error: {analysis['has_error']}")
        print(f"Has Revert: {analysis['has_revert']}")
        
        if verbose:
            print("\n--- Call Tree ---")
            print(analysis['call_tree'].tree_repr())


def batch_analyze(output_dir: Path) -> dict:
    """Analyze all trace files in a directory."""
    results = {}
    
    # Find all geth files and their besu counterparts
    for geth_file in output_dir.glob("*_geth.json"):
        scenario = geth_file.stem.replace("_geth", "")
        besu_file = output_dir / f"{scenario}_besu.json"
        
        if besu_file.exists():
            try:
                comparison = compare_trace_files(geth_file, besu_file)
                results[scenario] = {
                    "match": comparison["match"],
                    "differences": comparison["total_differences"],
                    "gas_discrepancies": len(comparison["gas_discrepancies"]),
                    "error_semantic_match": comparison["error_comparison"]["semantic_match"]
                }
            except Exception as e:
                results[scenario] = {"error": str(e)}
    
    return results


def main():
    parser = argparse.ArgumentParser(description="Analyze callTracer outputs")
    subparsers = parser.add_subparsers(dest="command")
    
    # Compare command
    compare_parser = subparsers.add_parser("compare", help="Compare Geth and Besu traces")
    compare_parser.add_argument("geth_file", type=Path, help="Geth trace JSON file")
    compare_parser.add_argument("besu_file", type=Path, help="Besu trace JSON file")
    compare_parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    
    # Analyze command
    analyze_parser = subparsers.add_parser("analyze", help="Analyze a single trace file")
    analyze_parser.add_argument("trace_file", type=Path, help="Trace JSON file")
    analyze_parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    
    # Batch command
    batch_parser = subparsers.add_parser("batch", help="Analyze all traces in a directory")
    batch_parser.add_argument(
        "output_dir",
        type=Path,
        default=Path("output/scenarios"),
        nargs="?",
        help="Directory containing trace files"
    )
    batch_parser.add_argument("--json", action="store_true", help="Output as JSON")
    
    # Tree command
    tree_parser = subparsers.add_parser("tree", help="Show call tree visualization")
    tree_parser.add_argument("trace_file", type=Path, help="Trace JSON file")
    
    # Diff command
    diff_parser = subparsers.add_parser("diff", help="Show JSON diff between traces")
    diff_parser.add_argument("geth_file", type=Path, help="Geth trace JSON file")
    diff_parser.add_argument("besu_file", type=Path, help="Besu trace JSON file")
    diff_parser.add_argument("--normalize", action="store_true", help="Normalize before diff")
    
    args = parser.parse_args()
    
    if args.command == "compare":
        analysis = compare_trace_files(args.geth_file, args.besu_file)
        print_analysis(analysis, args.verbose)
        
    elif args.command == "analyze":
        analysis = analyze_trace_file(args.trace_file)
        print_analysis(analysis, args.verbose)
        
    elif args.command == "batch":
        results = batch_analyze(args.output_dir)
        if args.json:
            print(json.dumps(results, indent=2))
        else:
            print("Batch Analysis Results")
            print("=" * 60)
            passed = 0
            failed = 0
            for scenario, result in sorted(results.items()):
                if "error" in result:
                    status = f"✗ ERROR: {result['error']}"
                    failed += 1
                elif result["match"]:
                    status = "✓ PASS"
                    passed += 1
                else:
                    status = f"✗ FAIL ({result['differences']} diffs, {result['gas_discrepancies']} gas)"
                    failed += 1
                print(f"{scenario}: {status}")
            print(f"\nTotal: {passed} passed, {failed} failed")
        
    elif args.command == "tree":
        with open(args.trace_file) as f:
            data = json.load(f)
        trace = data.get("result", {})
        tree = CallNode.from_trace(trace)
        print(tree.tree_repr())
        
    elif args.command == "diff":
        with open(args.geth_file) as f:
            geth_data = json.load(f)
        with open(args.besu_file) as f:
            besu_data = json.load(f)
        
        geth_trace = geth_data.get("result", {})
        besu_trace = besu_data.get("result", {})
        
        if args.normalize:
            geth_trace = normalize_call_trace(geth_trace)
            besu_trace = normalize_call_trace(besu_trace)
        
        diff = format_json_diff(geth_trace, besu_trace)
        if diff:
            print(diff)
        else:
            print("No differences found")
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
