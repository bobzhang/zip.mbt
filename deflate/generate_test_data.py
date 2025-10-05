#!/usr/bin/env python3
"""
Generate test data for DEFLATE implementation verification.
This script creates various test cases using Python's zlib module (which implements RFC 1951)
and outputs them in a format that can be used to test the MoonBit implementation.
"""

import zlib
import json
import sys
from typing import List, Dict, Any

def bytes_to_hex(data: bytes) -> str:
    """Convert bytes to hex string representation."""
    return data.hex()

def bytes_to_moonbit_array(data: bytes) -> str:
    """Convert bytes to MoonBit byte array literal."""
    if len(data) == 0:
        return 'b""'
    # Format as b"\x01\x02\x03..."
    hex_str = ''.join(f'\\x{b:02x}' for b in data)
    return f'b"{hex_str}"'

def create_test_case(name: str, input_data: bytes, level: int = -1) -> Dict[str, Any]:
    """
    Create a test case by compressing data with Python's zlib.
    
    Args:
        name: Test case name
        input_data: Raw input bytes to compress
        level: Compression level (0-9, -1 for default)
    
    Returns:
        Dict with test case information
    """
    # Compress with DEFLATE (raw, no zlib wrapper)
    # wbits=-15 means raw DEFLATE without zlib header/trailer
    compressor = zlib.compressobj(level=level, method=zlib.DEFLATED, wbits=-15)
    compressed = compressor.compress(input_data) + compressor.flush()
    
    # Decompress to verify
    decompressed = zlib.decompress(compressed, wbits=-15)
    assert decompressed == input_data, "Decompression verification failed"
    
    return {
        "name": name,
        "input_hex": bytes_to_hex(input_data),
        "input_moonbit": bytes_to_moonbit_array(input_data),
        "compressed_hex": bytes_to_hex(compressed),
        "compressed_moonbit": bytes_to_moonbit_array(compressed),
        "input_length": len(input_data),
        "compressed_length": len(compressed),
        "level": level if level != -1 else "default",
        "compression_ratio": f"{len(compressed) / max(len(input_data), 1):.2%}"
    }

def generate_test_cases() -> List[Dict[str, Any]]:
    """Generate a comprehensive set of test cases."""
    test_cases = []
    
    # 1. Empty data
    test_cases.append(create_test_case("empty", b"", level=6))
    
    # 2. Single byte
    test_cases.append(create_test_case("single_byte", b"A", level=6))
    
    # 3. Short repeated data (good compression)
    test_cases.append(create_test_case("repeated_10", b"A" * 10, level=6))
    test_cases.append(create_test_case("repeated_100", b"A" * 100, level=6))
    test_cases.append(create_test_case("repeated_1000", b"A" * 1000, level=6))
    
    # 4. ASCII text (typical use case)
    test_cases.append(create_test_case(
        "hello_world",
        b"Hello, World!",
        level=6
    ))
    
    test_cases.append(create_test_case(
        "lorem_ipsum",
        b"Lorem ipsum dolor sit amet, consectetur adipiscing elit. " * 10,
        level=6
    ))
    
    # 5. Binary data (poor compression)
    test_cases.append(create_test_case(
        "binary_sequence",
        bytes(range(256)),
        level=6
    ))
    
    # 6. Highly compressible pattern
    test_cases.append(create_test_case(
        "pattern_abc",
        b"abcabcabc" * 100,
        level=6
    ))
    
    # 7. Mixed content
    test_cases.append(create_test_case(
        "mixed",
        b"The quick brown fox jumps over the lazy dog. " * 20 + bytes(range(50)),
        level=6
    ))
    
    # 8. All zeros (maximum compression)
    test_cases.append(create_test_case("zeros_100", b"\x00" * 100, level=6))
    test_cases.append(create_test_case("zeros_1000", b"\x00" * 1000, level=6))
    
    # 9. Different compression levels for the same data
    sample_text = b"The quick brown fox jumps over the lazy dog. " * 10
    for level in [0, 1, 6, 9]:
        level_name = ["none", "fast", "default", "best"][level if level <= 1 else (2 if level == 6 else 3)]
        test_cases.append(create_test_case(
            f"level_{level_name}",
            sample_text,
            level=level
        ))
    
    # 10. Pathological cases
    test_cases.append(create_test_case(
        "alternating",
        b"01" * 500,
        level=6
    ))
    
    test_cases.append(create_test_case(
        "long_match",
        b"abc" + b"X" * 258 + b"def",  # Max match length is 258
        level=6
    ))
    
    # 11. Real-world-like JSON
    json_data = json.dumps({
        "users": [
            {"id": i, "name": f"User{i}", "email": f"user{i}@example.com"}
            for i in range(20)
        ]
    }, indent=2).encode()
    test_cases.append(create_test_case("json_data", json_data, level=6))
    
    # 12. Large data (test performance)
    test_cases.append(create_test_case(
        "large_text",
        (b"The quick brown fox jumps over the lazy dog. " * 1000),
        level=6
    ))
    
    return test_cases

def generate_moonbit_test_file(test_cases: List[Dict[str, Any]]) -> str:
    """Generate a MoonBit test file from test cases."""
    lines = [
        "// Auto-generated test cases from Python zlib (RFC 1951 reference implementation)",
        "// Generated by generate_test_data.py",
        "//",
        "// These tests verify that the MoonBit DEFLATE implementation produces",
        "// results compatible with Python's zlib module.",
        "",
    ]
    
    for i, tc in enumerate(test_cases, 1):
        lines.append("///|")
        lines.append(f'/// Test case {i}: {tc["name"]}')
        lines.append(f'/// Input length: {tc["input_length"]}, Compressed: {tc["compressed_length"]}, Ratio: {tc["compression_ratio"]}')
        lines.append(f'test "python_compat_{tc["name"]}" {{')
        lines.append(f'  // Input data')
        lines.append(f'  let input = {tc["input_moonbit"]}')
        lines.append(f'  ')
        lines.append(f'  // Expected compressed output from Python zlib (level={tc["level"]})')
        lines.append(f'  let expected_compressed = {tc["compressed_moonbit"]}')
        lines.append(f'  ')
        lines.append(f'  // Test decompression: our inflate should handle Python\'s output')
        lines.append(f'  let decompressed = @deflate.inflate(expected_compressed, 0, expected_compressed.length(), Some(input.length()))')
        lines.append(f'  @json.inspect(decompressed == input, content=true)')
        lines.append(f'  ')
        lines.append(f'  // Test compression: verify round-trip works')
        lines.append(f'  // Note: Our output may differ from Python\'s (different encoder decisions)')
        lines.append(f'  // but should decompress to the same input')
        lines.append(f'  guard @deflate.deflate(input, 0, input.length()) is Ok(our_compressed) else {{')
        lines.append(f'    fail("Failed to compress data")')
        lines.append(f'  }}')
        lines.append(f'  let roundtrip = @deflate.inflate(our_compressed, 0, our_compressed.length(), Some(input.length()))')
        lines.append(f'  @json.inspect(roundtrip == input, content=true)')
        lines.append(f'}}')
        lines.append("")
    
    return "\n".join(lines)

def main():
    """Main entry point."""
    print("Generating DEFLATE test cases using Python zlib...\n", file=sys.stderr)
    
    test_cases = generate_test_cases()
    
    # Output JSON summary
    summary = {
        "total_cases": len(test_cases),
        "generator": "Python zlib",
        "standard": "RFC 1951",
        "test_cases": test_cases
    }
    
    # Write JSON file
    with open("deflate/test_data.json", "w") as f:
        json.dump(summary, f, indent=2)
    print(f"✓ Generated test_data.json with {len(test_cases)} test cases", file=sys.stderr)
    
    # Generate MoonBit test file
    moonbit_test = generate_moonbit_test_file(test_cases)
    with open("deflate/deflate_python_compat_test.mbt", "w") as f:
        f.write(moonbit_test)
    print(f"✓ Generated deflate_python_compat_test.mbt", file=sys.stderr)
    
    # Print summary
    print(f"\nTest Cases Summary:", file=sys.stderr)
    print(f"{'Name':<25} {'Input':<8} {'Compressed':<10} {'Ratio':<8} {'Level'}", file=sys.stderr)
    print("=" * 70, file=sys.stderr)
    for tc in test_cases:
        print(f"{tc['name']:<25} {tc['input_length']:<8} {tc['compressed_length']:<10} {tc['compression_ratio']:<8} {tc['level']}", file=sys.stderr)
    
    print(f"\nTo run tests:", file=sys.stderr)
    print(f"  moon test --target wasm-gc -p deflate", file=sys.stderr)

if __name__ == "__main__":
    main()
