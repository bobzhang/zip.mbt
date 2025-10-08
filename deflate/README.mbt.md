# deflate - DEFLATE Compression/Decompression

**Level**: 2  
**Package**: `bobzhang/zip/deflate`  
**Dependencies**: `buffer`, `bitstream`, `huffman`, `lz77`, `crc32`, `adler32`

## Overview

The `deflate` package implements the complete DEFLATE compression algorithm (RFC 1951), combining LZ77 string matching with Huffman coding. This is the core compression format used in ZIP, gzip, and PNG files.

## Features

- **Full RFC 1951 Compliance**: Complete DEFLATE implementation
- **Multiple Compression Modes**:
  - Stored (uncompressed) blocks
  - Fixed Huffman coding
  - Dynamic Huffman coding
- **Inflate (Decompression)**: Fast, streaming decompression
- **Deflate (Compression)**: Multiple quality levels
- **Checksum Integration**: CRC-32 and Adler-32 support
- **Lazy Matching**: Optimal LZ77 compression

## Compression Formats

### 1. Stored Blocks (No Compression)
```
deflate_stored(data : BytesView) -> Bytes
```
- No compression, just wraps data in DEFLATE format
- Useful for already-compressed data
- 5 bytes overhead per 65535-byte block

### 2. Fixed Huffman
```
deflate_fixed(data : BytesView, is_final : Bool, good_match : Int, max_chain : Int) -> Bytes
```
- Uses predefined Huffman trees (RFC 1951)
- No header overhead for tree description
- Good for small data or streaming
- Combines LZ77 + Fixed Huffman

### 3. Dynamic Huffman
```
deflate_dynamic(data : BytesView, is_final : Bool, good_match : Int, max_chain : Int) -> Bytes
```
- Builds optimal Huffman trees for the data
- Better compression than fixed Huffman
- Small header overhead (~50-200 bytes)
- Best for larger data (>256 bytes)

## API

### Inflation (Decompression)

#### `inflate(src : BytesView, decompressed_size : Int?) -> Bytes`

Decompress DEFLATE data from a bytes view. Optional expected decompressed size
is used purely as a capacity hint; the function still validates actual sizes.

Helpers `inflate_and_crc32` / `inflate_and_adler32` were removed to keep the
API minimal. Use:
```
let decompressed = inflate(compressed[0:compressed.length()], Some(expected_len))
let crc32 = @crc32.bytes_crc32(decompressed[:])
let adler32 = @adler32.bytes_adler32(decompressed[:])
```

### Deflation (Compression)

#### `deflate_stored(data : BytesView) -> Bytes`

Create uncompressed DEFLATE blocks.

**Use case:** When data is incompressible or already compressed (wraps raw slice in a single stored block)

#### `deflate_fixed_literals_only(bytes, start, len, is_final) -> Bytes`

Compress using fixed Huffman without LZ77 matching.

**Use case:** Testing, education, or when LZ77 provides no benefit

#### `deflate_fixed(data : BytesView, is_final : Bool, good_match : Int, max_chain : Int) -> Bytes`

Compress using LZ77 + Fixed Huffman.

**Parameters:**
- `data` - Input slice to compress (use `bytes[start:start+len]` to select a region)
- `is_final` - Whether this is the final block (sets BFINAL)
- `good_match` - Early-exit match length threshold
- `max_chain` - Maximum LZ77 hash chain traversal depth

**Use case:** Fast compression, small data, streaming

#### `deflate_dynamic(data : BytesView, is_final : Bool, good_match : Int, max_chain : Int) -> Bytes`

Compress using LZ77 + Dynamic Huffman.

**Parameters:** Same fields as `deflate_fixed` (operates on a BytesView slice)

**Use case:** Best compression for larger data (>256 bytes)

### Helper Functions

#### Symbol Conversion

```
pub fn length_to_symbol(length : Int) -> Int
pub fn distance_to_symbol(dist : Int) -> Int
```

Convert LZ77 match lengths/distances to DEFLATE symbols.

#### Huffman Encoding

```
pub fn write_literal_symbol(writer, encoder, symbol) -> Unit
pub fn write_length_distance(writer, litlen_encoder, dist_encoder, length, distance) -> Unit
```

Low-level functions for writing Huffman-encoded symbols.

## Usage Examples

### Basic Compression

```moonbit
///|
test {
  let data = b"Hello, DEFLATE compression!"

  // Compress with default settings
  let compressed = @deflate.deflate_dynamic(
    data[0:data.length()],
    true,
    8,
    1024,
  )

  // Decompress
  let decompressed = @deflate.inflate(compressed[0:compressed.length()])
  @json.inspect(decompressed.length(), content=27)
}
```

### With Checksums

```
// Compress and get CRC-32
let compressed = deflate_dynamic(data[0:data.length()], true, 8, 1024)
// (Former helper inflate_and_crc32 removed) Explicit pattern:
let decompressed = inflate(compressed[0:compressed.length()], decompressed_size=data.length())
let crc = @crc32.bytes_crc32(decompressed[:])
```

### Compression Levels

```
// Fast compression (Level 1)
let fast = deflate_fixed(data, 0, len, true, 4, 128)

// Default compression (Level 6)
let default = deflate_dynamic(data, 0, len, true, 8, 1024)

// Maximum compression (Level 9)
let best = deflate_dynamic(data, 0, len, true, 32, 4096)
```

### Multi-Block Compression

```
let block_size = 32768
let blocks = []

for i = 0; i < data.length(); i += block_size {
  let len = (data.length() - i).min(block_size)
  let is_final = (i + len >= data.length())
  let block = deflate_dynamic(data, i, len, is_final, 8, 1024)
  blocks.push(block)
}

// Concatenate blocks
let compressed = concat_bytes(blocks)
```

## Compression Quality Parameters

### `good_match` - Early Exit Threshold

| Value | Behavior | Speed | Compression |
|-------|----------|-------|-------------|
| 4 | Stop at 4-byte match | Fastest | Lower |
| 8 | Stop at 8-byte match | Balanced | Good |
| 32 | Stop at 32-byte match | Slower | Best |

### `max_chain` - Search Depth

| Value | Behavior | Speed | Compression |
|-------|----------|-------|-------------|
| 128 | Check 128 positions | Fastest | Lower |
| 1024 | Check 1024 positions | Balanced | Good |
| 4096 | Check 4096 positions | Slowest | Best |

## Algorithm Overview

### Compression Pipeline

```
Input Data
    ↓
LZ77 String Matching
    ↓
(literals + length/distance pairs)
    ↓
Frequency Analysis
    ↓
Huffman Tree Construction
    ↓
Huffman Encoding
    ↓
Bit Packing
    ↓
Compressed Output
```

### Decompression Pipeline

```
Compressed Data
    ↓
Bit Unpacking
    ↓
Block Header Parsing
    ↓
Huffman Tree Reconstruction
    ↓
Symbol Decoding
    ↓
LZ77 Back-Reference Expansion
    ↓
Decompressed Output
```

## Block Format

### Block Header (3 bits)
```
BFINAL (1 bit):  1 = final block, 0 = more blocks
BTYPE (2 bits):  00 = stored, 01 = fixed Huffman, 10 = dynamic Huffman
```

### Stored Block
```
- Skip to byte boundary
- LEN (2 bytes, little-endian)
- NLEN (2 bytes, one's complement of LEN)
- Raw data (LEN bytes)
```

### Fixed Huffman Block
```
- Encoded symbols using predefined trees
- Symbols: literals (0-255), length (257-285), end-of-block (256)
- Distance codes follow length codes
```

### Dynamic Huffman Block
```
- HLIT (5 bits): # of literal codes - 257
- HDIST (5 bits): # of distance codes - 1
```
deflate_dynamic(data : BytesView, is_final : Bool, good_match : Int, max_chain : Int) -> Bytes
```
- Literal/length code lengths (encoded)
#### `deflate_dynamic(data : BytesView, is_final : Bool, good_match : Int, max_chain : Int) -> Bytes`
- Encoded data
#### `deflate_dynamic(data : BytesView, is_final : Bool, good_match : Int, max_chain : Int) -> Bytes`
    let compressed = @deflate.deflate_dynamic(data[0:data.length()], true, 8, 1024)
// Compress and get CRC-32
let compressed = deflate_dynamic(data[0:data.length()], true, 8, 1024)
let default = deflate_dynamic(data[0:len], true, 8, 1024)
let best = deflate_dynamic(data[0:len], true, 32, 4096)
    let block = deflate_dynamic(data[i:i + len], is_final, 8, 1024)

- **Compression**: ~100KB (hash tables + buffers)
- **Decompression**: ~300KB (Huffman trees + output buffer)
- **No streaming**: Processes entire block in memory

## Testing

Run tests with:
```bash
moon test deflate
```

Tests include:
- Empty data
- Single byte
- Repetitive data (best case for LZ77)
- Random data (worst case)
- All compression modes
- Round-trip compression/decompression
- Checksum validation
- RFC 1951 test vectors

## Dependencies

- `buffer` (Level 0) - For byte assembly
- `bitstream` (Level 1) - For bit-level I/O
- `huffman` (Level 1) - For Huffman coding
- `lz77` (Level 1) - For string matching
- `crc32` (Level 0) - For checksum (optional)
- `adler32` (Level 0) - For checksum (optional)

## Used By

- Main `zip` package - For ZIP file compression
- Can be used standalone for DEFLATE compression

## Standards Compliance

Fully implements:
- **RFC 1951** - DEFLATE Compressed Data Format Specification
  - All three block types (stored, fixed, dynamic)
  - Complete Huffman coding
  - Full LZ77 implementation
  - Proper bit-level encoding

Compatible with:
- gzip compressed files
- PNG image compression
- ZIP archive format
- zlib format (with wrapper)

## Implementation Notes

### Compression Optimizations

1. **Lazy Matching**: Defers encoding to find better matches
2. **Early Exit**: Stops search at "good enough" match
3. **Hash Chains**: Fast O(1) position lookup
4. **Frequency Counting**: Single-pass for dynamic Huffman

### Decompression Optimizations

1. **Bit Buffering**: Reads multiple bytes at once
2. **Tree-Based Lookup**: Fast symbol decoding
3. **Output Buffering**: Minimizes small writes
4. **In-Place Expansion**: LZ77 back-references

### Known Limitations

1. **Block Size**: Processes one block at a time (no streaming)
2. **Memory**: Requires full output buffer allocation
3. **No ZIP64**: Blocks limited to 4GB (DEFLATE format limit)

## Future Enhancements

Potential improvements:
- Streaming compression/decompression
- Better hash functions (more sophisticated than 4-byte)
- Parallel block compression
- Hardware acceleration (SIMD)
- Better Huffman tree construction (Package-Merge algorithm)

## References

- [RFC 1951 - DEFLATE Specification](https://www.rfc-editor.org/rfc/rfc1951)
- [RFC 1950 - zlib Format](https://www.rfc-editor.org/rfc/rfc1950)
- Deutsch, L. Peter (1996). "DEFLATE Compressed Data Format Specification"
- ZIP File Format Specification by PKWARE
