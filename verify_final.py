#!/usr/bin/env python3
import zlib

# Test specific byte values and the long string
test_cases = [
    b"\x00",
    b"\x01", 
    b"\x02",
    b"Hello, World! This is a longer test string."
]

for data in test_cases:
    crc = zlib.crc32(data) & 0xffffffff
    print(f"{data!r}: 0x{crc:08x} ({crc})")