#!/usr/bin/env python3
import zlib

# Verify specific test cases used in the Adler32 tests
test_cases = [
    (b"world", "world"),
    (b"hell", "hell"),
    (b"ello", "ello"),
    (b" world", "space world"),
    (b"A" * 100, "100 A's"),
]

for data, desc in test_cases:
    adler = zlib.adler32(data) & 0xffffffff
    print(f"{desc}: 0x{adler:08x} ({adler})")