#!/usr/bin/env python3
"""
Direct comparison between Python's zlib.crc32 and our MoonBit implementation
This script generates test cases and verifies our implementation is correct
"""

import zlib
import subprocess
import tempfile
import os

def create_moonbit_test(test_cases):
    """Create a MoonBit test file to compare with Python results"""
    
    moonbit_code = '''
// Direct comparison test with Python's zlib.crc32
'''
    
    for i, (data, description) in enumerate(test_cases):
        # Convert bytes to MoonBit byte literal
        if isinstance(data, bytes):
            if len(data) == 0:
                data_str = 'b""'
            elif all(32 <= b <= 126 and b != 92 and b != 34 for b in data):  # printable ASCII, no quotes or backslashes
                try:
                    data_str = f'b"{data.decode("ascii")}"'
                except UnicodeDecodeError:
                    data_str = f'b"\\x{data.hex()}"'
            else:
                # Use hex representation for non-printable bytes
                hex_chars = []
                for b in data:
                    hex_chars.append(f'\\x{b:02x}')
                data_str = 'b"' + ''.join(hex_chars) + '"'
        
        python_crc = zlib.crc32(data) & 0xffffffff
        
        moonbit_code += f'''
test "python_comparison_{i:02d}_{description.replace(" ", "_")}" {{
  let data = {data_str}
  let crc = @crc32.bytes_crc32(data, 0, data.length())
  // Python: zlib.crc32({data!r}) = 0x{python_crc:08x} ({python_crc})
  inspect!(crc, content="{python_crc}")
}}
'''
    
    return moonbit_code

def main():
    test_cases = [
        (b"", "empty"),
        (b"a", "single_a"),
        (b"abc", "abc"),
        (b"hello", "hello"),
        (b"hello world", "hello_world"),
        (b"123456789", "numbers"),
        (b"The quick brown fox jumps over the lazy dog", "quick_fox"),
        (bytes([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]), "binary_0_to_15"),
        (b"A" * 50, "fifty_As"),
        (bytes(range(32, 127)), "printable_ascii"),
    ]
    
    print("Python CRC32 Reference Values:")
    print("=" * 50)
    
    for i, (data, description) in enumerate(test_cases):
        python_crc = zlib.crc32(data) & 0xffffffff
        print(f"{i:2d}. {description:20s}: 0x{python_crc:08x} ({python_crc:>10d}) - {len(data):3d} bytes")
        if len(data) <= 20:
            print(f"    Data: {data!r}")
        else:
            print(f"    Data: {data[:10]!r}...{data[-10:]!r}")
    
    print("\n" + "=" * 50)
    print("Generating MoonBit test code...")
    
    moonbit_test_code = create_moonbit_test(test_cases)
    
    # Write to a file for manual verification
    with open('python_crc32_comparison.mbt', 'w') as f:
        f.write(moonbit_test_code)
    
    print("MoonBit test code written to: python_crc32_comparison.mbt")
    print("\nYou can copy this test code to verify your implementation!")

if __name__ == "__main__":
    main()