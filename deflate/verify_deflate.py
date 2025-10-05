#!/usr/bin/env python3
"""
Verify DEFLATE implementation by comparing with Python's zlib.

This script can:
1. Decompress MoonBit-generated DEFLATE data using Python
2. Compress test data with Python and compare with MoonBit output
3. Run comprehensive compatibility tests
"""

import zlib
import sys
import json
import argparse
from pathlib import Path
from typing import Optional, Tuple

def hex_to_bytes(hex_str: str) -> bytes:
    """Convert hex string to bytes."""
    return bytes.fromhex(hex_str.replace(" ", "").replace("\n", ""))

def moonbit_bytes_to_python(mb_str: str) -> bytes:
    """
    Convert MoonBit byte literal to Python bytes.
    Example: b"\\x01\\x02\\x03" -> bytes([1, 2, 3])
    """
    # Remove b" prefix and " suffix
    if mb_str.startswith('b"') and mb_str.endswith('"'):
        mb_str = mb_str[2:-1]
    
    # Parse escape sequences
    result = []
    i = 0
    while i < len(mb_str):
        if mb_str[i] == '\\' and i + 1 < len(mb_str):
            if mb_str[i+1] == 'x' and i + 3 < len(mb_str):
                # \xHH format
                hex_val = mb_str[i+2:i+4]
                result.append(int(hex_val, 16))
                i += 4
            elif mb_str[i+1] == 'n':
                result.append(ord('\n'))
                i += 2
            elif mb_str[i+1] == 't':
                result.append(ord('\t'))
                i += 2
            elif mb_str[i+1] == 'r':
                result.append(ord('\r'))
                i += 2
            elif mb_str[i+1] == '\\':
                result.append(ord('\\'))
                i += 2
            elif mb_str[i+1] == '"':
                result.append(ord('"'))
                i += 2
            else:
                result.append(ord(mb_str[i+1]))
                i += 2
        else:
            result.append(ord(mb_str[i]))
            i += 1
    
    return bytes(result)

def verify_decompress(compressed_hex: str, expected_hex: Optional[str] = None) -> Tuple[bool, str, bytes]:
    """
    Decompress DEFLATE data and optionally verify against expected output.
    
    Returns:
        (success, message, decompressed_data)
    """
    try:
        compressed = hex_to_bytes(compressed_hex)
        decompressed = zlib.decompress(compressed, wbits=-15)  # -15 for raw DEFLATE
        
        if expected_hex:
            expected = hex_to_bytes(expected_hex)
            if decompressed == expected:
                return (True, f"✓ Decompression successful ({len(decompressed)} bytes)", decompressed)
            else:
                return (False, f"✗ Decompression mismatch: got {len(decompressed)} bytes, expected {len(expected)} bytes", decompressed)
        else:
            return (True, f"✓ Decompression successful ({len(decompressed)} bytes)", decompressed)
    
    except zlib.error as e:
        return (False, f"✗ Decompression failed: {e}", b"")
    except Exception as e:
        return (False, f"✗ Error: {e}", b"")

def verify_compress(input_hex: str, moonbit_compressed_hex: str, level: int = 6) -> Tuple[bool, str]:
    """
    Compress data with Python and compare with MoonBit output.
    
    Note: Exact byte-for-byte match is unlikely due to encoder differences,
    but both should decompress to the same input.
    """
    try:
        input_data = hex_to_bytes(input_hex)
        moonbit_compressed = hex_to_bytes(moonbit_compressed_hex)
        
        # Compress with Python
        compressor = zlib.compressobj(level=level, method=zlib.DEFLATED, wbits=-15)
        python_compressed = compressor.compress(input_data) + compressor.flush()
        
        # Check if outputs match exactly (rare)
        if python_compressed == moonbit_compressed:
            return (True, f"✓ Exact match! Both produce {len(python_compressed)} bytes")
        
        # Verify both decompress to same input
        try:
            python_decompressed = zlib.decompress(python_compressed, wbits=-15)
            moonbit_decompressed = zlib.decompress(moonbit_compressed, wbits=-15)
            
            if python_decompressed == input_data and moonbit_decompressed == input_data:
                return (True, 
                    f"✓ Both decompress correctly (Python: {len(python_compressed)} bytes, "
                    f"MoonBit: {len(moonbit_compressed)} bytes)")
            else:
                return (False, "✗ One or both decompression results don't match input")
        
        except zlib.error as e:
            return (False, f"✗ Decompression verification failed: {e}")
    
    except Exception as e:
        return (False, f"✗ Error: {e}")

def verify_roundtrip(input_hex: str) -> Tuple[bool, str]:
    """Test compression and decompression roundtrip with Python."""
    try:
        input_data = hex_to_bytes(input_hex)
        
        # Compress
        compressor = zlib.compressobj(level=6, method=zlib.DEFLATED, wbits=-15)
        compressed = compressor.compress(input_data) + compressor.flush()
        
        # Decompress
        decompressed = zlib.decompress(compressed, wbits=-15)
        
        if decompressed == input_data:
            ratio = len(compressed) / max(len(input_data), 1) * 100
            return (True, f"✓ Roundtrip successful: {len(input_data)} → {len(compressed)} bytes ({ratio:.1f}%)")
        else:
            return (False, "✗ Roundtrip failed: decompressed data doesn't match input")
    
    except Exception as e:
        return (False, f"✗ Roundtrip error: {e}")

def interactive_mode():
    """Interactive mode for testing."""
    print("DEFLATE Verification Tool (Python zlib)")
    print("=" * 50)
    print()
    print("Commands:")
    print("  decompress <hex>     - Decompress DEFLATE data")
    print("  compress <hex>       - Compress and show result")
    print("  roundtrip <hex>      - Test compress/decompress")
    print("  quit                 - Exit")
    print()
    
    while True:
        try:
            line = input("> ").strip()
            if not line:
                continue
            
            parts = line.split(maxsplit=1)
            cmd = parts[0].lower()
            
            if cmd == "quit" or cmd == "exit":
                break
            
            if len(parts) < 2:
                print("Error: Missing argument")
                continue
            
            hex_data = parts[1]
            
            if cmd == "decompress":
                success, msg, data = verify_decompress(hex_data)
                print(msg)
                if success and len(data) < 200:
                    print(f"Data: {data}")
            
            elif cmd == "compress":
                try:
                    input_data = hex_to_bytes(hex_data)
                    compressor = zlib.compressobj(level=6, method=zlib.DEFLATED, wbits=-15)
                    compressed = compressor.compress(input_data) + compressor.flush()
                    print(f"✓ Compressed: {len(input_data)} → {len(compressed)} bytes")
                    print(f"Hex: {compressed.hex()}")
                except Exception as e:
                    print(f"✗ Error: {e}")
            
            elif cmd == "roundtrip":
                success, msg = verify_roundtrip(hex_data)
                print(msg)
            
            else:
                print(f"Unknown command: {cmd}")
        
        except KeyboardInterrupt:
            print()
            break
        except EOFError:
            break
        except Exception as e:
            print(f"Error: {e}")

def main():
    parser = argparse.ArgumentParser(
        description="Verify DEFLATE implementation against Python's zlib"
    )
    parser.add_argument(
        "--decompress",
        metavar="HEX",
        help="Decompress hex-encoded DEFLATE data"
    )
    parser.add_argument(
        "--compress",
        metavar="HEX",
        help="Compress hex-encoded input data"
    )
    parser.add_argument(
        "--roundtrip",
        metavar="HEX",
        help="Test roundtrip with hex-encoded data"
    )
    parser.add_argument(
        "--interactive",
        action="store_true",
        help="Start interactive mode"
    )
    parser.add_argument(
        "--level",
        type=int,
        default=6,
        choices=range(0, 10),
        help="Compression level (0-9, default: 6)"
    )
    
    args = parser.parse_args()
    
    if args.interactive:
        interactive_mode()
        return
    
    if args.decompress:
        success, msg, data = verify_decompress(args.decompress)
        print(msg)
        if success and len(data) < 500:
            print(f"\nDecompressed data:")
            try:
                print(data.decode('utf-8'))
            except:
                print(data)
        sys.exit(0 if success else 1)
    
    elif args.compress:
        try:
            input_data = hex_to_bytes(args.compress)
            compressor = zlib.compressobj(level=args.level, method=zlib.DEFLATED, wbits=-15)
            compressed = compressor.compress(input_data) + compressor.flush()
            print(f"✓ Compressed {len(input_data)} → {len(compressed)} bytes")
            print(f"Hex: {compressed.hex()}")
            sys.exit(0)
        except Exception as e:
            print(f"✗ Error: {e}")
            sys.exit(1)
    
    elif args.roundtrip:
        success, msg = verify_roundtrip(args.roundtrip)
        print(msg)
        sys.exit(0 if success else 1)
    
    else:
        parser.print_help()
        print("\nOr run with --interactive for interactive mode")

if __name__ == "__main__":
    main()
