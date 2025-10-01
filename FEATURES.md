# zipc Feature Implementation Checklist

This document tracks the port of zipc from OCaml to MoonBit.

## Module 1: zipc_deflate - Checksums ✅

- [x] CRC-32 checksum with lookup table
- [x] CRC-32 incremental updates
- [x] CRC-32 validation
- [x] Adler-32 checksum with block processing
- [x] Adler-32 incremental updates
- [x] Adler-32 validation
- [x] Tests for both checksums

## Module 2: zipc_deflate - Huffman Coding

### Deflate Constants ✅
- [x] Literal/length symbol constants (max, counts, etc.)
- [x] Length value table (symbol 257-285 → length 3-258)
- [x] Distance symbol constants
- [x] Distance value table (symbol 0-29 → distance 1-32768)
- [x] Code length symbol order (for dynamic blocks)

### Huffman Decoder ✅
- [x] Decoder structure (counts, symbols, max_sym)
- [x] Fixed literal/length decoder (RFC 1951 3.2.6)
- [x] Fixed distance decoder
- [ ] Dynamic decoder initialization from code lengths
- [ ] Symbol decoding from bit stream

### Huffman Encoder
- [ ] Encoder structure (symbol info array)
- [ ] Build Huffman tree from frequencies
- [ ] Compute canonical codes
- [ ] Fixed literal/length encoder
- [ ] Fixed distance encoder
- [ ] Dynamic encoder from frequencies

## Module 3: zipc_deflate - Inflate (Decompression)

### Bit Stream Reading
- [ ] Bit buffer for reading
- [ ] Read N bits from stream
- [ ] Byte-aligned reading

### Block Decompression
- [ ] Read uncompressed blocks
- [ ] Read fixed Huffman blocks
- [ ] Read dynamic Huffman blocks
- [ ] Decode literal/length symbols
- [ ] Decode distance symbols
- [ ] Back-reference copying

### High-level API
- [ ] inflate() - decompress deflate stream
- [ ] inflate_and_crc_32() - with CRC-32
- [ ] inflate_and_adler_32() - with Adler-32
- [ ] zlib_decompress() - decompress zlib format

## Module 4: zipc_deflate - Deflate (Compression)

### LZ77 String Matching
- [ ] Rabin-Karp hash-based matching
- [ ] Hash table for match positions
- [ ] Find longest match
- [ ] Lazy matching optimization

### Block Compression
- [ ] Collect symbols (literals and back-refs)
- [ ] Compute symbol frequencies
- [ ] Choose block type (stored/fixed/dynamic)
- [ ] Write uncompressed blocks
- [ ] Write fixed Huffman blocks
- [ ] Write dynamic Huffman blocks

### Code Length Encoding
- [ ] Encode code lengths with RLE (symbols 16, 17, 18)
- [ ] Build code length Huffman tree

### High-level API
- [ ] deflate() - compress to deflate stream
- [ ] crc_32_and_deflate() - with CRC-32
- [ ] adler_32_and_deflate() - with Adler-32
- [ ] zlib_compress() - compress to zlib format

## Module 5: zipc - Utilities

### Fpath (File Paths)
- [ ] ensure_unix() - convert backslashes
- [ ] ensure_directoryness() - add trailing slash
- [ ] sanitize() - remove dangerous path segments
- [ ] pp_mode() - format Unix file modes

### Ptime (POSIX Time)
- [ ] dos_epoch constant (1980-01-01)
- [ ] to_date_time() - convert to (y,m,d),(h,m,s)
- [ ] of_dos_date_time() - from MS-DOS format
- [ ] to_dos_date_time() - to MS-DOS format
- [ ] pp() - format as RFC 3339

## Module 6: zipc - File Data

- [ ] File structure (compression metadata)
- [ ] make() - create file data
- [ ] stored_of_binary_string() - no compression
- [ ] deflate_of_binary_string() - with deflate
- [ ] Property accessors (compression, size, CRC, etc.)
- [ ] is_encrypted() predicate
- [ ] can_extract() predicate
- [ ] to_binary_string() - decompress file data
- [ ] to_binary_string_no_crc_check()

## Module 7: zipc - Archive Members

- [ ] Member structure (path, kind, mode, mtime)
- [ ] Member kind (Dir or File)
- [ ] make() - create member
- [ ] Property accessors
- [ ] pp() - format member info
- [ ] pp_long() - verbose format

## Module 8: zipc - ZIP Archive

### Archive Operations
- [ ] Archive structure (map of members)
- [ ] empty - create empty archive
- [ ] is_empty() - check if empty
- [ ] mem() - check if path exists
- [ ] find() - find member by path
- [ ] fold() - iterate over members
- [ ] add() - add/replace member
- [ ] remove() - remove member
- [ ] member_count() - count members
- [ ] to_string_map() / of_string_map()

### ZIP Decoding
- [ ] string_has_magic() - check ZIP signature
- [ ] Parse End of Central Directory (EOCD)
- [ ] Parse Central Directory File Headers (CDFH)
- [ ] Parse Local File Headers (LFH)
- [ ] of_binary_string() - decode ZIP archive

### ZIP Encoding
- [ ] encoding_size() - calculate size needed
- [ ] Encode Local File Headers
- [ ] Encode file data
- [ ] Encode Central Directory
- [ ] Encode EOCD
- [ ] to_binary_string() - encode ZIP archive
- [ ] write_bytes() - encode to existing buffer

## Testing Strategy

For each module:
1. Unit tests for basic functionality
2. Property tests where applicable
3. Integration tests with real ZIP files
4. Roundtrip tests (encode → decode)
5. Compatibility tests with standard ZIP tools

## Current Status

- **Completed**: 
  - Checksums (CRC-32, Adler-32) ✅
  - Deflate constants and symbol tables ✅
  - Huffman decoder structures ✅
- **Next**: Bit stream reading and inflate implementation
- **Progress**: ~15% complete (~530 / ~2500 lines)

## Summary by Lines of Code

| Module | Total Lines | Completed | Percentage |
|--------|-------------|-----------|------------|
| Checksums | ~140 | ~140 | 100% |
| Deflate Constants | ~250 | ~250 | 100% |
| Huffman Decoder | ~100 | ~50 | 50% |
| Huffman Encoder | ~180 | 0 | 0% |
| Inflate | ~220 | 0 | 0% |
| Deflate | ~500 | 0 | 0% |
| Utilities | ~200 | 0 | 0% |
| File/Member | ~300 | 0 | 0% |
| ZIP Archive | ~600 | 0 | 0% |
| **Total** | **~2500** | **~530** | **~21%** |
