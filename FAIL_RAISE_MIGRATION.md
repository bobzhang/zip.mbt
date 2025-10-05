# Migration from abort() to fail() with raise Error Handling

## Summary

Successfully migrated error handling in the zip.mbt project from uncatchable `abort()` panics to catchable `fail()` errors with proper `raise` annotations for error propagation.

## Changes Made

### Core deflate.mbt (22 abort → fail conversions)

**Functions marked with `raise`:**
- `InflateDecoder::read_bits(count: Int) -> Int raise`
- `InflateDecoder::read_int(base, bit_count) -> Int raise`
- `read_symbol_loop(...) -> Int raise`
- `InflateDecoder::read_symbol(decoder) -> Int raise`
- `read_block_symbols(decoder, litlen, dist) -> Unit raise`
- `read_uncompressed_block(decoder) -> Unit raise`
- `read_fixed_block(decoder) -> Unit raise`
- `read_dynamic_block(decoder) -> Unit raise`
- `inflate_loop(decoder) -> Bytes raise`
- `inflate(src, start, len, size) -> Bytes raise`
- `inflate_and_crc32(...) -> (Bytes, UInt) raise`
- `inflate_and_adler32(...) -> (Bytes, UInt) raise`
- `zlib_decompress(bytes, start, len) -> (Bytes, UInt) raise`
- `deflate_stored(bytes, start, len) -> Bytes raise`
- `deflate(bytes, start, len, level?) -> Bytes raise`
- `crc32_and_deflate(...) -> (UInt, Bytes) raise`
- `adler32_and_deflate(...) -> (UInt, Bytes) raise`

**Error conditions converted (22 total):**
1. Line 192: Unexpected end of deflate data
2. Line 271: Invalid literal/length symbol
3. Line 282: Invalid distance symbol
4. Line 291: Distance too large (back-reference)
5. Line 307: Truncated uncompressed block
6. Line 319: Invalid uncompressed block length
7. Line 324: Truncated uncompressed block data
8. Line 348: Invalid dynamic block header
9. Line 365: Empty code length code
10. Line 375: Invalid code length symbol
11. Line 381: Repeat with no previous code
12. Line 394: Code length repeat too long
13. Line 404: Missing end-of-block code
14. Line 428: Invalid block type
15. Line 435: Unreachable code path
16. Line 511: Deflate compression not implemented for large data
17. Line 1359: Zlib data too short
18. Line 1367: Invalid compression method
19. Line 1370: Invalid window size
20. Line 1381: Invalid zlib header checksum
21. Line 1384: Preset dictionary not supported
22. Line 1408: Adler-32 checksum mismatch

### file/file.mbt (3 abort → fail conversions)

**Functions marked with `raise`:**
- `File::to_bytes_no_crc_check() -> (Bytes, UInt) raise`
- `File::to_bytes() -> Bytes raise`

**Error conditions:**
1. Line 343: Encrypted files not supported
2. Line 365: Unsupported compression format
3. Line 376: CRC-32 checksum mismatch

## API Changes

### Before (Result-based)
```moonbit
fn inflate(src, start, len, size) -> Result[Bytes, String]
fn deflate(bytes, start, len, level?) -> Result[Bytes, String]
fn zlib_decompress(bytes, start, len) -> Result[(Bytes, UInt), String]
```

### After (raise-based)
```moonbit
fn inflate(src, start, len, size) -> Bytes raise
fn deflate(bytes, start, len, level?) -> Bytes raise
fn zlib_decompress(bytes, start, len) -> (Bytes, UInt) raise
```

## Error Propagation

MoonBit's `raise` keyword enables automatic error propagation:

1. **Function Declaration**: Add `raise` to return type
   ```moonbit
   fn my_function() -> ReturnType raise { ... }
   ```

2. **Error Throwing**: Use `fail("message")` (not `fail!`)
   ```moonbit
   if error_condition {
     fail("Error message")
   }
   ```

3. **Error Propagation**: Errors automatically propagate through call chains
   ```moonbit
   // No explicit ? or ! needed - automatic propagation
   let result = error_raising_function()
   ```

## Test Results

- **Total tests**: 270
- **Passed**: 270 ✅
- **Failed**: 0 ✅
- **Compilation errors**: 0 ✅

## Benefits

1. **Catchable Errors**: Errors can now be caught and handled with try/catch
2. **Better Error Reporting**: Detailed error messages propagate through call stack
3. **Type Safety**: Compiler enforces error handling with `raise` annotation
4. **Cleaner API**: Direct return values instead of Result wrapping
5. **Performance**: No Result allocation overhead

## Notes

- The `!` suffix syntax is deprecated in MoonBit; use `raise` keyword instead
- Error propagation is automatic in functions with `raise` - no explicit `?` needed
- `fail()` throws catchable errors; `abort()` causes uncatchable panics
- All 22 error paths in deflate.mbt now use catchable `fail()`
- Test files updated to work with direct value returns instead of Result types

## Verified By

- `moon check`: 0 compilation errors
- `moon test`: 270/270 tests passing
- `moon fmt && moon info`: Generated interfaces updated successfully
