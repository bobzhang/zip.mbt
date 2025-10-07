#!/usr/bin/env python3
import zlib

# Verify specific test cases
test_cases = [
    (b"A", "single A"),
    (b"A" * 100, "100 A's"),
    (b"world", "world"),
    (b"hell", "hell"),
    (b"ello", "ello"),
    (b" world", "space world"),
]

for data, desc in test_cases:
    crc = zlib.crc32(data) & 0xffffffff
    print(f"{desc}: 0x{crc:08x} ({crc})")