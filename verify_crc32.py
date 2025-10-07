#!/usr/bin/env python3
"""
Verify CRC32 implementation against Python's zlib.crc32
"""

import zlib
import binascii

def test_cases():
    """Generate test cases with expected CRC32 values from Python"""
    test_data = [
        b"",
        b"a",
        b"abc",
        b"hello",
        b"hello world",
        b"The quick brown fox jumps over the lazy dog",
        b"123456789",
        b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f",
        b"A" * 1000,  # Large repeated data
        bytes(range(256)),  # All byte values
    ]
    
    print("// Python CRC32 test vectors")
    print("// Generated using Python's zlib.crc32")
    print()
    
    for i, data in enumerate(test_data):
        crc = zlib.crc32(data) & 0xffffffff  # Ensure unsigned 32-bit
        
        # Create a readable representation of the data
        if len(data) == 0:
            data_repr = 'b""'
            desc = "empty"
        elif len(data) <= 20:
            try:
                data_str = data.decode('ascii')
                if all(32 <= ord(c) <= 126 for c in data_str):  # printable ASCII
                    data_repr = f'b"{data_str}"'
                    desc = data_str
                else:
                    data_repr = f"b\"{binascii.hexlify(data).decode()}\""
                    desc = f"hex:{binascii.hexlify(data).decode()}"
            except UnicodeDecodeError:
                data_repr = f"bytes([{', '.join(str(b) for b in data)}])"
                desc = f"hex:{binascii.hexlify(data).decode()}"
        else:
            if data == b"A" * 1000:
                data_repr = 'b"A" * 1000'
                desc = "1000 A's"
            elif data == bytes(range(256)):
                data_repr = "bytes(range(256))"
                desc = "all bytes 0-255"
            else:
                data_repr = f"<{len(data)} bytes>"
                desc = f"{len(data)} bytes"
        
        print(f"Test case {i}: {desc}")
        print(f"  Data: {data_repr}")
        print(f"  Length: {len(data)}")
        print(f"  CRC32: 0x{crc:08x} ({crc})")
        print()
        
        # Also test incremental calculation
        if len(data) > 1:
            mid = len(data) // 2
            crc1 = zlib.crc32(data[:mid]) & 0xffffffff
            crc2 = zlib.crc32(data[mid:], crc1) & 0xffffffff
            print(f"  Incremental test (split at {mid}):")
            print(f"    Part 1 CRC32: 0x{crc1:08x}")
            print(f"    Final CRC32: 0x{crc2:08x}")
            print(f"    Matches: {crc2 == crc}")
            print()

if __name__ == "__main__":
    test_cases()