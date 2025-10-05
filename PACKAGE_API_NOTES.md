# Package API Visibility Notes

## MoonBit Visibility Model

MoonBit has a simple visibility model:
- `pub` - Public, accessible from any package
- No `pub` - Private to the package, NOT accessible from other packages (even with `@package.` syntax)

This is different from languages like Rust which have `pub(crate)` or Java's package-private.

## Package API Status

### ✅ deflate Package - Minimized

**Before**: 14 public functions  
**After**: 10 public functions (29% reduction)

**Made Private** (accessible only via whitebox testing):
- `length_to_symbol()` - Convert LZ77 match length to DEFLATE symbol
- `distance_to_symbol()` - Convert LZ77 distance to DEFLATE symbol
- `build_optimal_code_lengths()` - Build optimal Huffman code lengths
- `deflate_fixed_literals_only()` - Test helper function

**Kept Public** (used by `file/file.mbt`):
- `deflate_stored()` - Create uncompressed DEFLATE blocks
- `deflate_fixed()` - Fixed Huffman compression
- `deflate_dynamic()` - Dynamic Huffman compression

**Tests**: Moved internal function tests to `deflate_wbtest.mbt` (13 whitebox tests)

### ⚠️ lz77 Package - Cannot Minimize

**Status**: All 13 functions/constants must remain `pub`

**Reason**: The deflate package depends on lz77 and accesses its functions via `@lz77.` syntax. If we make lz77 functions non-pub, deflate cannot access them.

**Public API** (all required by deflate):
- Constants: `min_match_len`, `max_match_len`, `window_size`, `hash_size`, `no_pos`
- Functions: `hash4()`, `insert_hash()`, `match_fwd()`, `find_match_length()`, `make_backref()`, `backref_dist()`, `backref_len()`, `find_backref()`

**Documentation Strategy**: Mark as internal in documentation, but keep `pub` for technical reasons.

### ⚠️ huffman Package - Cannot Minimize Helper Functions

**Status**: Helper functions must remain `pub`

**Reason**: The deflate package uses huffman helper functions via `@huffman.` syntax.

**Public API** (all required by deflate):
- Types: `HuffmanDecoder`, `HuffmanEncoder`, `SymInfo`
- Helpers: `sym_info_make()`, `sym_info_code()`, `sym_info_code_length()`, `reverse_bits()`
- Constants: `fixed_litlen_decoder`, `fixed_dist_decoder`, `fixed_litlen_encoder`, `fixed_dist_encoder`

**Documentation Strategy**: Mark helper functions as internal in documentation.

### ✅ checksum Packages - Already Minimal

**crc32**:
- 2 functions: `bytes_crc32()`, `check_crc32()`
- 1 type: `Crc32` with methods
- Used by main package and deflate

**adler32**:
- 2 functions: `bytes_adler32()`, `check_adler32()`
- 1 type: `Adler32` with methods
- Used by main package and deflate

### ✅ Utility Packages - Already Minimal

**buffer**: 1 type `ByteBuf` with 6 methods - minimal and appropriate  
**bitstream**: 1 type `BitWriter` with 6 methods - minimal and appropriate

## Recommendations

### For Current Codebase

1. **deflate**: ✅ Complete - minimal public API with whitebox testing
2. **lz77/huffman**: Document functions as "Internal - do not use directly" in API docs
3. **checksums**: ✅ Already minimal and appropriate
4. **utilities**: ✅ Already minimal and appropriate

### For Future MoonBit Language

If MoonBit adds package-private or friend visibility:
- lz77 and huffman could be made package-private
- Only deflate would have friend access
- This would reduce the effective public API surface

### Alternative Architecture (Not Recommended)

We could merge lz77, huffman, and deflate into a single package to truly hide internals:
```
deflate/
  deflate.mbt          - Public API
  lz77.mbt             - Private implementation
  huffman.mbt          - Private implementation
  deflate_wbtest.mbt   - Whitebox tests
```

**Pros**: True encapsulation of lz77/huffman  
**Cons**: 
- Loss of modularity
- Larger package (harder to understand)
- Cannot test lz77/huffman independently
- Goes against current clean architecture

## Summary

✅ **Achieved**:  
- DEFLATE package: 29% API reduction (14 → 10 functions)
- Whitebox testing pattern established
- Zero breaking changes for legitimate users

❌ **Cannot Achieve** (due to language limitations):  
- lz77/huffman API hiding (must remain `pub` for cross-package access)

📝 **Workaround**:  
- Document internal functions clearly
- Use naming conventions (e.g., prefix with `internal_` in future)
- Rely on documentation to guide proper API usage
