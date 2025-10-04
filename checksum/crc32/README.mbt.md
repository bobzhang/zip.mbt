# crc32 - CRC-32 Checksum

**Level**: 0 (no dependencies)  
**Package**: `bobzhang/zip/checksum/crc32`

## Overview

The `crc32` package implements the CRC-32 checksum algorithm as used in ZIP archives, gzip, and PNG files. It uses the IEEE 802.3 polynomial (0xEDB88320) for compatibility with standard implementations.

## Features

- **Standard Algorithm**: IEEE 802.3 CRC-32 (used by ZIP, gzip, PNG)
- **Table-Driven**: Fast computation using 256-entry lookup table
- **Byte Range Support**: Calculate CRC for a slice of a byte array
- **Validation Helper**: Check computed vs expected CRC with error messages

## API

### Types



Type alias for CRC-32 values (32-bit unsigned integer).

### Functions

#### `bytes_crc32(bytes : Bytes, start : Int, len : Int) -> Crc32`

Compute CRC-32 checksum for a byte range.

**Parameters:**
- `bytes` - Source byte array
- `start` - Starting offset
- `len` - Number of bytes to process

**Returns:** 32-bit CRC-32 checksum

#### `check_crc32(expect : Crc32, found : Crc32) -> Result[Unit, String]`

Validate a CRC-32 checksum.

**Parameters:**
- `expect` - Expected checksum value
- `found` - Computed checksum value

**Returns:** `Ok(())` if checksums match, `Err(message)` if they don't

## Algorithm Details

The CRC-32 computation follows this pattern:

```
crc = 0xFFFFFFFF
for each byte b:
  crc = (crc >> 8) ^ table[(crc ^ b) & 0xFF]
result = crc ^ 0xFFFFFFFF
```

The lookup table is precomputed using the IEEE 802.3 polynomial: `0xEDB88320`

## Usage Example

```moonbit
///|
test {
  let data = b"Hello, World!"
  let crc = bytes_crc32(data, 0, data.length())
  println("CRC-32: 0x\{crc.reinterpret_as_int().to_string(radix=16)}")
  @json.inspect(crc, content=3964322768)
}
```

## Test Vectors

The implementation is validated against known test vectors:

| Input | CRC-32 (hex) |
|-------|--------------|
| Empty string | 0x00000000 |
| "123456789" | 0xCBF43926 |

## Performance

- **O(n)** time complexity where n is the number of bytes
- Uses a 256-entry lookup table (1KB) for fast computation
- No additional memory allocation during computation

## Standards Compliance

This implementation conforms to:
- IEEE 802.3 (Ethernet) CRC-32
- ISO 3309
- ITU-T V.42
- ZIP file format (PKZIP)
- gzip file format
- PNG image format

## Dependencies

None - This is a Level 0 package.

## Used By

- Main `zip` package - For file integrity verification
- `deflate` package - For compressed data validation

## Testing

Run tests with:
```bash
moon test checksum/crc32
```

Tests include:
- Empty data
- Standard test vectors
- Various data sizes
- Checksum validation
