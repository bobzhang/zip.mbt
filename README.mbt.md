# bobzhang/zip

A pure MoonBit implementation of ZIP archive format with full DEFLATE compression support.

## Features

### ✅ Complete Implementation

- **ZIP Format (PKZIP 2.0)**
  - Local file headers
  - Central directory
  - End of central directory
  - Archive creation and extraction
  - Member management

- **DEFLATE Compression (RFC 1951)**
  - Inflate (decompression): Fixed & Dynamic Huffman, Stored blocks
  - Deflate (compression): LZ77 string matching with lazy evaluation
  - Fixed Huffman encoding
  - **Dynamic Huffman encoding** (5-15% better compression)
  - Block type selection (Stored/Fixed/Dynamic)
  - Multiple compression levels (None/Fast/Default/Best)

- **zlib Wrapper (RFC 1950)**
  - CMF/FLG headers with FCHECK validation
  - Adler-32 checksum
  - Compatible with standard zlib tools

- **Checksums**
  - CRC-32 (for ZIP)
  - Adler-32 (for zlib)

### Compression Performance

- **None**: Stored blocks (no compression)
- **Fast**: Fixed Huffman with minimal LZ77 (fastest)
- **Default**: Dynamic Huffman with balanced LZ77 (recommended)
- **Best**: Dynamic Huffman with maximum LZ77 effort (best compression)

Dynamic Huffman automatically used for data ≥256 bytes, providing optimal compression ratios.

## Usage

See test files for comprehensive usage examples. Basic pattern:

1. Create file data: `File::deflate_of_bytes(bytes, start, len, level)`
2. Create member: `Member::make(name, kind, mod_time, comment)`
3. Build archive: `Archive::empty().add(member1).add(member2)...`
4. Encode: `archive.to_bytes(comment)`
5. Decode: `Archive::of_bytes(bytes)`
6. Extract: `archive.find(name)` or `archive.members_iter()`
7. Decompress: `inflate(compressed, start, size, max_size)`

## Test Coverage

**168 tests** covering:
- ZIP format encoding/decoding
- DEFLATE compression/decompression
- LZ77 string matching
- Fixed & Dynamic Huffman encoding
- zlib wrapper format
- Edge cases and error handling

All tests passing ✅

## Implementation Status

- ✅ ZIP format: 100%
- ✅ Inflate (decompress): 100%
- ✅ Deflate (compress): 100%
  - ✅ Stored blocks
  - ✅ Fixed Huffman
  - ✅ Dynamic Huffman
  - ✅ LZ77 with lazy matching
- ✅ zlib wrapper: 100%
- ✅ Checksums: 100%

## References

- [RFC 1950](https://tools.ietf.org/html/rfc1950) - zlib format
- [RFC 1951](https://tools.ietf.org/html/rfc1951) - DEFLATE format
- [RFC 1952](https://tools.ietf.org/html/rfc1952) - gzip format
- [PKWARE ZIP specification](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT)

