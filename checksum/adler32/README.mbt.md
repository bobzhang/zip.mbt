# adler32 - Adler-32 Checksum

**Level**: 0 (no dependencies)  
**Package**: `bobzhang/zip/checksum/adler32`

## Overview

The `adler32` package implements the Adler-32 checksum algorithm as defined in RFC 1950 (zlib format). Adler-32 is faster than CRC-32 but provides slightly weaker error detection.

## Features

- **Standard Algorithm**: RFC 1950 Adler-32 (used by zlib/deflate)
- **Fast Computation**: Faster than CRC-32, no lookup table needed
- **Byte Range Support**: Calculate checksum for a slice of a byte array
// Validation helper `check_adler32` removed (compare values directly)

## API

### Types



Type alias for Adler-32 values (32-bit unsigned integer).

### Functions

#### `bytes_adler32(data : BytesView) -> Adler32`

Compute Adler-32 checksum for a byte slice (view). The entire view is processed.

**Parameters:**
- `data` - BytesView slice to checksum

**Returns:** 32-bit Adler-32 checksum

// `check_adler32` removed from API (use simple equality comparison)

## Algorithm Details

Adler-32 maintains two 16-bit sums (modulo 65521):

```
s1 = 1
s2 = 0
for each byte b:
  s1 = (s1 + b) mod 65521
  s2 = (s2 + s1) mod 65521
result = (s2 << 16) | s1
```

**Key constant:** `BASE = 65521` (largest prime less than 2^16)

## Usage Example

```moonbit
///|
test {
  let data = b"Hello, World!"
  let adler = @adler32.bytes_adler32(data[:])
  println("Adler-32: 0x\{adler.reinterpret_as_int().to_string(radix=16)}")
  @json.inspect(adler, content=530449514)
}
```

## Test Vectors

The implementation is validated against known test vectors:

| Input | Adler-32 (hex) |
|-------|----------------|
| Empty string | 0x00000001 |
| "abc" | 0x024D0127 |
| "message digest" | 0x29750586 |
| "abcdefghijklmnopqrstuvwxyz" | 0x90860B20 |

## Performance Characteristics

- **Speed**: Significantly faster than CRC-32
  - No lookup table required
  - Simple addition operations
- **Error Detection**: Good but slightly weaker than CRC-32
  - Detects single-byte errors
  - Detects burst errors
  - Less effective for certain error patterns
- **Time Complexity**: O(n) where n is the number of bytes
- **Space Complexity**: O(1) - no additional memory allocation

## When to Use

**Use Adler-32 when:**
- Speed is more important than maximum error detection
- Used in zlib/deflate compressed data streams
- Data integrity is also verified by other means (e.g., compression format)

**Use CRC-32 when:**
- Maximum error detection is critical
- Compatibility with ZIP file format is required
- Slightly slower computation is acceptable

## Standards Compliance

This implementation conforms to:
- RFC 1950 (zlib Compressed Data Format Specification)
- Used in zlib library
- Used in PNG image format (for chunk CRCs, but PNG uses CRC-32)

## Dependencies

None - This is a Level 0 package.

## Used By

- Main `zip` package - For zlib format support
- `deflate` package - For zlib wrapper validation

## Testing

Run tests with:
```bash
moon test checksum/adler32
```

Tests include:
- Empty data
- Standard test vectors from RFC 1950
- Various data sizes
- Checksum validation
- Comparison with known implementations
