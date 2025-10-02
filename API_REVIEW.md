# API Surface Review and Minimization Plan

## Current State

After reviewing all `pkg.generated.mbti` files, the packages are exposing far too many internal implementation details. This document outlines what should be exposed vs. what should remain private.

## Main Package (`bobzhang/zip`)

### ✅ Should Remain Public

**Core Types:**
- `Archive` - Main ZIP archive type with all methods
- `Member` - ZIP member (file or directory) with all methods  
- `File` - Compressed file data with all methods
- `MemberKind` - Enum for Dir/File variants
- `DeflateLevel` - Enum for compression levels (None/Fast/Default/Best)

**Type Aliases (Re-exports):**
- `Compression` - From types package
- `Fpath` - File path type
- `Ptime` - POSIX time type  
- `FileMode` - File permission mode

**Essential Functions:**
- `inflate(Bytes, Int, Int, Int?) -> Bytes` - Decompress DEFLATE data
- `inflate_and_crc32(Bytes, Int, Int, Int?) -> (Bytes, Int64)` - With CRC-32
- `inflate_and_adler32(Bytes, Int, Int, Int?) -> (Bytes, Int64)` - With Adler-32
- `bytes_crc32(Bytes, Int, Int) -> Int64` - Calculate CRC-32
- `bytes_adler32(Bytes, Int, Int) -> Int64` - Calculate Adler-32
- `check_crc32(Int64, Int64) -> Result[Unit, String]` - Validate CRC-32
- `check_adler32(Int64, Int64) -> Result[Unit, String]` - Validate Adler-32

**Utility Functions (from types):**
- `fpath_ensure_unix(String) -> String`
- `fpath_ensure_directoryness(String) -> String`
- `fpath_sanitize(String) -> String`
- `ptime_to_date_time(Int) -> ((Int, Int, Int), (Int, Int, Int))`
- `ptime_of_dos_date_time(Int, Int) -> Int`
- `ptime_to_dos_date_time(Int) -> (Int, Int)`
- `ptime_format(Int) -> String`
- `format_file_mode(Int) -> String`

### ❌ Should Be Made Private

**DEFLATE Internal Functions (currently exposed via re-exports):**
- `deflate_stored()` - Internal compression mode
- `deflate_fixed()` - Internal compression mode
- `deflate_dynamic()` - Internal compression mode
- `deflate_fixed_literals_only()` - Internal optimization
- `deflate()` - Internal (used via `File::deflate_of_bytes`)
- `crc32_and_deflate()` - Internal
- `adler32_and_deflate()` - Internal
- `zlib_compress()` - Internal (maybe should be public?)
- `zlib_decompress()` - Internal (maybe should be public?)

**LZ77 Internal Functions:**
- `hash4()` - Hash function
- `insert_hash()` - Hash table insertion
- `find_backref()` - String matching
- `make_backref()` - Backref encoding
- `backref_len()` - Backref decoding
- `backref_dist()` - Backref decoding
- `match_fwd()` - Match length calculation
- `find_match_length()` - Match length calculation

**Huffman Internal Functions:**
- `sym_info_make()` - Symbol encoding
- `sym_info_code()` - Symbol decoding
- `sym_info_code_length()` - Symbol decoding
- `reverse_bits()` - Bit manipulation
- `write_literal_symbol()` - DEFLATE encoding
- `write_length_distance()` - DEFLATE encoding

**Internal Constants:**
- `fixed_litlen_encoder` - Huffman table
- `fixed_dist_encoder` - Huffman table
- `fixed_litlen_decoder` - Huffman table
- `fixed_dist_decoder` - Huffman table
- `dist_value_of_sym` - Lookup table
- `length_value_of_sym_table` - Lookup table
- `litlen_end_of_block_sym` - DEFLATE constant
- `litlen_first_len_sym` - DEFLATE constant
- `litlen_sym_max` - DEFLATE constant
- `dist_sym_max` - DEFLATE constant
- `max_litlen_sym_count` - DEFLATE constant
- `max_dist_sym_count` - DEFLATE constant
- `max_codelen_sym_count` - DEFLATE constant
- `codelen_order_of_sym_lengths` - DEFLATE constant
- `gp_flag_encrypted` - ZIP constant
- `gp_flag_utf8` - ZIP constant
- `dos_epoch` - Time constant
- `max_file_size` - ZIP limit
- `max_member_count` - ZIP limit
- `max_path_length` - ZIP limit

**Internal Functions:**
- `length_to_symbol()` - DEFLATE encoding
- `distance_to_symbol()` - DEFLATE encoding
- `bytes_has_zip_magic()` - Internal validation

**Type:**
- `FrequencyCounter` - Internal DEFLATE state (should not be exposed)

## Sub-Packages

### deflate Package

**Should Expose:**
- `deflate_stored()` - For use by main package
- `deflate_fixed()` - For use by main package
- `deflate_dynamic()` - For use by main package
- `inflate()` - For use by main package
- `inflate_and_crc32()` - For use by main package
- `inflate_and_adler32()` - For use by main package

**Should Be Private:**
- `build_canonical_huffman()` - Internal
- `build_optimal_code_lengths()` - Internal
- `encode_code_lengths()` - Internal
- `write_dynamic_header()` - Internal
- `write_literal_symbol()` - Internal
- `write_length_distance()` - Internal
- `length_to_symbol()` - Internal
- `distance_to_symbol()` - Internal
- `length_value_of_length_sym()` - Internal
- All constants (codelen_order, dist_sym_max, etc.)
- `FrequencyCounter` struct - Internal
- `InflateDecoder` struct - Internal

### lz77 Package

**All functions should be private** (only used by deflate package):
- `hash4()`
- `insert_hash()`
- `find_backref()`
- `make_backref()`
- `backref_len()`
- `backref_dist()`
- `match_fwd()`
- `find_match_length()`
- All constants (hash_bit_size, hash_size, max_match_dist, etc.)

### huffman Package

**Should Expose (for deflate package):**
- `HuffmanDecoder` struct
- `HuffmanEncoder` struct  
- `fixed_litlen_decoder` constant
- `fixed_dist_decoder` constant
- `fixed_litlen_encoder` constant
- `fixed_dist_encoder` constant

**Should Be Private:**
- `sym_info_make()`
- `sym_info_code()`
- `sym_info_code_length()`
- `reverse_bits()`
- `litlen_sym_max` constant
- `litlen_sym_fixed_max` constant
- `dist_sym_max` constant

### buffer Package

**Current API is reasonable** - ByteBuf is used by multiple packages

### bitstream Package

**Current API is reasonable** - BitWriter is used by deflate package

### types Package

**Should Expose:**
- `Compression` enum with all variants
- All ptime functions
- All fpath functions
- `dos_epoch` constant

**Consider:**
- Whether `Compression::from_int()` and `to_int()` should be public

### types/fpath Package

**All functions should remain public** (utility functions)

### Checksum Packages (crc32, adler32)

**Current APIs are reasonable** - Clean checksum computation interfaces

### hexdump Package

**Current API is fine** - Simple utility function

## Implementation Strategy

### Phase 1: Mark Functions as Private (Non-Breaking Changes)

Make functions private that are only used internally within the same package.

### Phase 2: Review Cross-Package Dependencies

Ensure packages that need functions from other packages can still access them. May need to:
1. Use `pub(readonly)` for read-only exposure
2. Keep some functions public but document as "internal use only"
3. Refactor to reduce dependencies

### Phase 3: Update Documentation

Update all README files to clearly indicate which APIs are:
- Public and stable
- Public but internal (use at own risk)
- Private (not accessible)

### Phase 4: Version and Communicate

Since this is a significant API surface reduction, should be done carefully:
1. Document all changes
2. Provide migration guide if needed
3. Consider semantic versioning implications

## Recommendations

### Option A: Aggressive Minimization (Recommended)

Only expose high-level APIs in main package:
- Archive operations
- Member operations  
- File operations
- Basic compression/decompression (inflate family)
- Checksum functions
- Utility functions (fpath, ptime, format_file_mode)

All implementation details (DEFLATE internals, LZ77, Huffman) remain private.

### Option B: Conservative Approach

Keep some lower-level APIs public for advanced users:
- DEFLATE compression modes (stored, fixed, dynamic)
- zlib wrapper functions
- Maybe FrequencyCounter for custom compression

### Option C: Current State

Leave everything exposed (not recommended - leaks implementation details)

## Decision

**Recommend Option A** - Aggressive minimization. Users should interact with the high-level Archive/Member/File API. If they need low-level compression, they can use `File::deflate_of_bytes()` or `File::stored_of_bytes()`.

The internal DEFLATE, LZ77, and Huffman implementations are not meant for direct use and exposing them creates maintenance burden and potential for misuse.

## Action Items

1. ✅ Review all pkg.generated.mbti files
2. ✅ Create this API review document
3. ⏳ Make functions private in main package (remove `pub` keywords)
4. ⏳ Make functions private in deflate package
5. ⏳ Make functions private in lz77 package  
6. ⏳ Make functions private in huffman package
7. ⏳ Regenerate pkg.generated.mbti files
8. ⏳ Run full test suite
9. ⏳ Update documentation
10. ⏳ Commit changes

## Notes

- MoonBit's module system uses `pub` for public visibility
- Functions without `pub` are private to the package
- Need to balance API surface vs. flexibility for advanced users
- Consider adding `@internal` or similar documentation tags for functions that must be public for internal use but shouldn't be used by external consumers
