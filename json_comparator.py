"""
JSON comparison utilities for callTracer output analysis.

Provides deep JSON comparison with semantic understanding of Ethereum
callTracer structures, including normalization and diff generation.
"""

import json
from typing import Any, Optional
from dataclasses import dataclass, field
from collections.abc import Mapping, Sequence


@dataclass
class DiffResult:
    """Represents a difference found between two JSON structures."""
    path: str
    geth_value: Any
    besu_value: Any
    diff_type: str  # 'missing_in_besu', 'missing_in_geth', 'value_mismatch', 'type_mismatch'
    
    def __str__(self) -> str:
        if self.diff_type == 'missing_in_besu':
            return f"{self.path}: Missing in Besu (Geth has: {self.geth_value})"
        elif self.diff_type == 'missing_in_geth':
            return f"{self.path}: Missing in Geth (Besu has: {self.besu_value})"
        elif self.diff_type == 'type_mismatch':
            return (f"{self.path}: Type mismatch - "
                   f"Geth: {type(self.geth_value).__name__} vs Besu: {type(self.besu_value).__name__}")
        else:
            return f"{self.path}: Geth={self.geth_value} vs Besu={self.besu_value}"


@dataclass
class ComparisonResult:
    """Complete comparison result between Geth and Besu callTracer outputs."""
    is_match: bool
    differences: list[DiffResult] = field(default_factory=list)
    geth_normalized: Optional[dict] = None
    besu_normalized: Optional[dict] = None
    
    def summary(self) -> str:
        """Generate a human-readable summary of differences."""
        if self.is_match:
            return "✓ PASS: Results match exactly"
        
        lines = [f"✗ FAIL: Found {len(self.differences)} difference(s):"]
        
        # Group differences by type
        by_type: dict[str, list[DiffResult]] = {}
        for diff in self.differences:
            by_type.setdefault(diff.diff_type, []).append(diff)
        
        for diff_type, diffs in by_type.items():
            lines.append(f"\n  {diff_type.replace('_', ' ').title()} ({len(diffs)}):")
            for diff in diffs[:10]:  # Limit to first 10 per type
                lines.append(f"    - {diff}")
            if len(diffs) > 10:
                lines.append(f"    ... and {len(diffs) - 10} more")
        
        return '\n'.join(lines)
    
    def detailed_report(self) -> str:
        """Generate a detailed report suitable for debugging."""
        if self.is_match:
            return "Results match exactly - no differences found."
        
        lines = [
            "=" * 60,
            "DETAILED COMPARISON REPORT",
            "=" * 60,
            f"Total differences: {len(self.differences)}",
            ""
        ]
        
        for i, diff in enumerate(self.differences, 1):
            lines.extend([
                f"Difference #{i}:",
                f"  Path: {diff.path}",
                f"  Type: {diff.diff_type}",
                f"  Geth: {json.dumps(diff.geth_value, indent=4) if isinstance(diff.geth_value, (dict, list)) else diff.geth_value}",
                f"  Besu: {json.dumps(diff.besu_value, indent=4) if isinstance(diff.besu_value, (dict, list)) else diff.besu_value}",
                ""
            ])
        
        return '\n'.join(lines)


def normalize_call_trace(trace: dict) -> dict:
    """
    Normalize a callTracer result for comparison.
    
    This removes null/empty values and ensures consistent ordering,
    matching the normalization behavior in the bash script.
    """
    if not isinstance(trace, dict):
        return trace
    
    # Fields to include in normalized output (in order)
    fields = ['from', 'to', 'type', 'input', 'output', 'error', 'revertReason', 
              'gas', 'gasUsed', 'value', 'calls']
    
    normalized = {}
    
    for field in fields:
        if field in trace and trace[field] is not None:
            if field == 'calls':
                # Recursively normalize nested calls
                calls = trace[field]
                if isinstance(calls, list) and len(calls) > 0:
                    normalized['calls'] = [normalize_call_trace(call) for call in calls]
            else:
                normalized[field] = trace[field]
    
    return normalized


def normalize_hex_value(value: Any) -> Any:
    """Normalize hex values for comparison (handles 0x0 vs 0x00 differences)."""
    if isinstance(value, str) and value.startswith('0x'):
        # Remove leading zeros but keep at least one digit
        if len(value) > 2:
            stripped = value[2:].lstrip('0') or '0'
            return '0x' + stripped
    return value


def deep_normalize_hex(obj: Any) -> Any:
    """Recursively normalize all hex values in a structure."""
    if isinstance(obj, dict):
        return {k: deep_normalize_hex(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [deep_normalize_hex(item) for item in obj]
    else:
        return normalize_hex_value(obj)


def compare_json_recursive(
    geth_obj: Any,
    besu_obj: Any,
    path: str = "root",
    differences: Optional[list[DiffResult]] = None
) -> list[DiffResult]:
    """
    Recursively compare two JSON objects and collect all differences.
    """
    if differences is None:
        differences = []
    
    # Handle None/null cases
    if geth_obj is None and besu_obj is None:
        return differences
    
    if geth_obj is None:
        differences.append(DiffResult(path, None, besu_obj, 'missing_in_geth'))
        return differences
    
    if besu_obj is None:
        differences.append(DiffResult(path, geth_obj, None, 'missing_in_besu'))
        return differences
    
    # Type mismatch
    if type(geth_obj) != type(besu_obj):
        # Special case: int vs str for numeric comparisons
        if isinstance(geth_obj, (int, str)) and isinstance(besu_obj, (int, str)):
            geth_str = str(geth_obj)
            besu_str = str(besu_obj)
            if geth_str != besu_str:
                differences.append(DiffResult(path, geth_obj, besu_obj, 'value_mismatch'))
        else:
            differences.append(DiffResult(path, geth_obj, besu_obj, 'type_mismatch'))
        return differences
    
    # Compare dictionaries
    if isinstance(geth_obj, Mapping):
        all_keys = set(geth_obj.keys()) | set(besu_obj.keys())
        for key in sorted(all_keys):
            new_path = f"{path}.{key}"
            if key not in geth_obj:
                differences.append(DiffResult(new_path, None, besu_obj[key], 'missing_in_geth'))
            elif key not in besu_obj:
                differences.append(DiffResult(new_path, geth_obj[key], None, 'missing_in_besu'))
            else:
                compare_json_recursive(geth_obj[key], besu_obj[key], new_path, differences)
    
    # Compare lists/arrays
    elif isinstance(geth_obj, Sequence) and not isinstance(geth_obj, str):
        if len(geth_obj) != len(besu_obj):
            differences.append(DiffResult(
                f"{path}.length",
                len(geth_obj),
                len(besu_obj),
                'value_mismatch'
            ))
        # Compare elements up to the shorter length
        for i in range(min(len(geth_obj), len(besu_obj))):
            compare_json_recursive(geth_obj[i], besu_obj[i], f"{path}[{i}]", differences)
    
    # Compare primitive values
    else:
        if geth_obj != besu_obj:
            differences.append(DiffResult(path, geth_obj, besu_obj, 'value_mismatch'))
    
    return differences


def compare_call_traces(geth_result: dict, besu_result: dict, normalize: bool = True) -> ComparisonResult:
    """
    Compare Geth and Besu callTracer results.
    
    Args:
        geth_result: The 'result' field from Geth's debug_traceTransaction response
        besu_result: The 'result' field from Besu's debug_traceTransaction response
        normalize: Whether to normalize the traces before comparison
    
    Returns:
        ComparisonResult with detailed difference information
    """
    if normalize:
        geth_normalized = normalize_call_trace(geth_result)
        besu_normalized = normalize_call_trace(besu_result)
    else:
        geth_normalized = geth_result
        besu_normalized = besu_result
    
    # Optionally normalize hex values
    # geth_normalized = deep_normalize_hex(geth_normalized)
    # besu_normalized = deep_normalize_hex(besu_normalized)
    
    differences = compare_json_recursive(geth_normalized, besu_normalized)
    
    return ComparisonResult(
        is_match=len(differences) == 0,
        differences=differences,
        geth_normalized=geth_normalized,
        besu_normalized=besu_normalized
    )


def format_json_diff(geth_json: dict, besu_json: dict) -> str:
    """
    Generate a side-by-side or unified diff view of two JSON objects.
    """
    geth_lines = json.dumps(geth_json, indent=2, sort_keys=True).splitlines()
    besu_lines = json.dumps(besu_json, indent=2, sort_keys=True).splitlines()
    
    import difflib
    diff = difflib.unified_diff(
        geth_lines,
        besu_lines,
        fromfile='Geth',
        tofile='Besu',
        lineterm=''
    )
    
    return '\n'.join(diff)


def extract_gas_summary(trace: dict) -> dict:
    """Extract gas-related information from a trace for quick comparison."""
    summary = {
        'gas': trace.get('gas'),
        'gasUsed': trace.get('gasUsed'),
        'type': trace.get('type'),
    }
    
    if 'calls' in trace:
        summary['nested_calls'] = len(trace['calls'])
        summary['nested_gas'] = [
            {'gas': call.get('gas'), 'gasUsed': call.get('gasUsed'), 'type': call.get('type')}
            for call in trace['calls']
        ]
    
    return summary


def compare_gas_metrics(geth_trace: dict, besu_trace: dict) -> dict:
    """Compare gas metrics specifically between traces."""
    geth_gas = extract_gas_summary(geth_trace)
    besu_gas = extract_gas_summary(besu_trace)
    
    metrics = {
        'geth': geth_gas,
        'besu': besu_gas,
        'gas_match': geth_gas.get('gas') == besu_gas.get('gas'),
        'gasUsed_match': geth_gas.get('gasUsed') == besu_gas.get('gasUsed'),
    }
    
    if 'nested_calls' in geth_gas and 'nested_calls' in besu_gas:
        metrics['nested_count_match'] = geth_gas['nested_calls'] == besu_gas['nested_calls']
    
    return metrics


if __name__ == "__main__":
    # Example usage and testing
    example_geth = {
        "from": "0x123",
        "to": "0x456",
        "type": "CALL",
        "gas": "0x5208",
        "gasUsed": "0x5208",
        "input": "0x",
        "output": "0x",
        "value": "0x0"
    }
    
    example_besu = {
        "from": "0x123",
        "to": "0x456",
        "type": "CALL",
        "gas": "0x5208",
        "gasUsed": "0x5209",  # Intentional difference
        "input": "0x",
        "output": "0x",
        "value": "0x0"
    }
    
    result = compare_call_traces(example_geth, example_besu)
    print(result.summary())
    print("\nDetailed:")
    print(result.detailed_report())
