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
- [x] Dynamic decoder initialization from code lengths
- [x] Symbol decoding from bit stream

### Huffman Encoder
- [ ] Encoder structure (symbol info array)
- [ ] Build Huffman tree from frequencies
- [ ] Compute canonical codes
- [ ] Fixed literal/length encoder
- [ ] Fixed distance encoder
- [ ] Dynamic encoder from frequencies

## Module 3: zipc_deflate - Inflate (Decompression) ✅

### Bit Stream Reading ✅
- [x] Bit buffer for reading
- [x] Read N bits from stream
- [x] Read symbol with Huffman decoder
- [x] Byte buffer for output (ByteBuf)

### Block Decompression ✅
- [x] Read uncompressed blocks
- [x] Read fixed Huffman blocks
- [x] Read dynamic Huffman blocks
- [x] Decode literal/length symbols
- [x] Decode distance symbols
- [x] Back-reference copying with overlapping support

### High-level API ✅
- [x] inflate() - decompress deflate stream
- [x] inflate_and_crc_32() - with CRC-32
- [x] inflate_and_adler_32() - with Adler-32
- [ ] zlib_decompress() - decompress zlib format (need header/trailer)

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
1. Unit tests for basic functionality ✓
2. Property tests where applicable (pending)
3. Integration tests with real ZIP files (pending)
4. Roundtrip tests (encode → decode) (pending)
5. Compatibility tests with standard ZIP tools (pending)

## Current Status - 4 Commits

### Completed Modules:
1. **Checksums** (CRC-32, Adler-32) ✅ - 100%
2. **Deflate Constants & Symbol Tables** ✅ - 100%
3. **Huffman Decoder** ✅ - 100%
4. **Bit Stream Reading** ✅ - 100%
5. **Inflate (Decompression)** ✅ - 95% (missing zlib wrapper)

### Next Priority:
**Option A**: Complete inflate with zlib_decompress() - small addition
**Option B**: Jump to ZIP archive utilities (Fpath, Ptime) to enable File/Member
**Option C**: Implement deflate (compression) - larger undertaking

**Progress**: ~1150 / ~2690 lines (~43%)

## Summary by Lines of Code

| Module | Total Lines | Completed | Percentage |
|--------|-------------|-----------|------------|
| Checksums | ~140 | ~140 | 100% |
| Deflate Constants | ~250 | ~250 | 100% |
| Huffman Decoder | ~150 | ~150 | 100% |
| Bit Stream & ByteBuf | ~200 | ~200 | 100% |
| Inflate Blocks | ~220 | ~210 | 95% |
| Huffman Encoder | ~180 | 0 | 0% |
| Deflate/LZ77 | ~500 | 0 | 0% |
| Utilities (Fpath/Ptime) | ~200 | 0 | 0% |
| File/Member | ~300 | 0 | 0% |
| ZIP Archive | ~600 | 0 | 0% |
| **Total** | **~2740** | **~1150** | **~42%** |

## Files

- `zip.mbt`: 899 lines (main library)
- `zip_test.mbt`: 244 lines (20 tests, all passing)
- `FEATURES.md`: This tracking document
- `MIGRATION.md`: Migration notes
