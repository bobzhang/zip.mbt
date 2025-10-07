#!/usr/bin/env python3
import zlib

# Verify specific test cases for final verification
test_cases = [
    (b"\x00", "byte 0"),
    (b"\x01", "byte 1"),
    (b"\xff", "byte 255"),
    (b"Hello, World! This is a longer test string.", "long string"),
    (b"Z" * 1000, "1000 Z's"),
]

for data, desc in test_cases:
    adler = zlib.adler32(data) & 0xffffffff
    print(f"{desc}: 0x{adler:08x} ({adler})")