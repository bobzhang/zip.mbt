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

## Usage Examples

### Quick Start: Create and Extract ZIP Archives

```moonbit
///|
test "create_zip_with_deflate" {
  // Create files with DEFLATE compression
  let readme = b"# My Project\n\nThis is a sample project."
  let config = b"{ \"version\": \"1.0\", \"debug\": true }"

  // Compress files (using default compression level)
  let readme_file = @file.File::deflate_of_bytes(readme, 0, readme.length())
  let config_file = @file.File::deflate_of_bytes(config, 0, config.length())

  // Create members with filenames
  let m1 = @member.make("README.md", File(readme_file))
  let m2 = @member.make("config.json", File(config_file))

  // Build archive
  let archive = Archive::empty().add(m1).add(m2)

  // Encode to bytes
  let zip_bytes = archive.to_bytes()

  // Verify archive was created
  @json.inspect(zip_bytes.length() > 0, content=true)
}
```

### Roundtrip: Create, Save, Load, and Extract

```moonbit
///|
test "zip_roundtrip_with_compression" {
  // Original data - repetitive for good compression
  let data = b"The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog."

  // Create file with best compression
  let file = @file.File::deflate_of_bytes(
    data,
    0,
    data.length(),
    level=@deflate.DeflateLevel::Best,
  )
  let m = @member.make("document.txt", File(file))
  let archive = Archive::empty().add(m)

  // Encode to ZIP bytes
  let zip_bytes = archive.to_bytes()

  // Decode from ZIP bytes
  let decoded = Archive::of_bytes(zip_bytes)

  // Extract and verify
  guard decoded.find("document.txt") is Some(found) else {
    fail("File not found in archive")
  }
  guard found.kind() is File(f) else { fail("Expected file, not directory") }

  // Decompress and verify content matches
  let extracted = f.to_bytes()
  @json.inspect(extracted == data, content=true)

  // Check compression was effective
  @json.inspect(f.compressed_size() < data.length(), content=true)
}
```

### Working with Multiple Files

```moonbit
///|
test "zip_with_multiple_files" {
  // Create several files
  let main_mbt = b"fn main() { println(\"Hello, MoonBit!\") }"
  let utils_mbt = b"fn helper() -> Int { 42 }"
  let readme_md = b"# Project Documentation\n\nMoonBit project files."

  // Compress each file
  let file1 = @file.File::deflate_of_bytes(main_mbt, 0, main_mbt.length())
  let file2 = @file.File::deflate_of_bytes(utils_mbt, 0, utils_mbt.length())
  let file3 = @file.File::deflate_of_bytes(readme_md, 0, readme_md.length())

  // Build archive with all files
  let archive = Archive::empty()
    .add(@member.make("src/main.mbt", File(file1)))
    .add(@member.make("src/utils.mbt", File(file2)))
    .add(@member.make("README.md", File(file3)))

  // Encode and decode
  let zip_bytes = archive.to_bytes()
  let decoded = Archive::of_bytes(zip_bytes)

  // Verify all files present
  @json.inspect(decoded.find("src/main.mbt").is_empty(), content=false)
  @json.inspect(decoded.find("src/utils.mbt").is_empty(), content=false)
  @json.inspect(decoded.find("README.md").is_empty(), content=false)
}
```

### Comparing Compression Levels

```moonbit
///|
test "compression_levels_comparison" {
  // Highly compressible data
  let data = b"aaabbbcccdddeeefffggghhhiiijjjkkklllmmmnnn"

  // Try different compression levels
  let none = @file.File::deflate_of_bytes(
    data,
    0,
    data.length(),
    level=@deflate.DeflateLevel::None,
  )
  let fast = @file.File::deflate_of_bytes(
    data,
    0,
    data.length(),
    level=@deflate.DeflateLevel::Fast,
  )
  let best = @file.File::deflate_of_bytes(
    data,
    0,
    data.length(),
    level=@deflate.DeflateLevel::Best,
  )

  // None (stored) should be largest
  @json.inspect(none.compressed_size() > fast.compressed_size(), content=true)

  // Best should be smallest
  @json.inspect(best.compressed_size() <= fast.compressed_size(), content=true)

  // All should decompress to same data
  @json.inspect(
    (none.to_bytes() == data, fast.to_bytes() == data, best.to_bytes() == data),
    content=[true, true, true],
  )
}
```

### Error Handling with Catchable Exceptions

```moonbit
///|
test "error_handling_example" {
  // Create valid archive
  let data = b"test data"
  let file = @file.File::deflate_of_bytes(data, 0, data.length())
  let m = @member.make("test.txt", File(file))
  let archive = Archive::empty().add(m)
  let zip_bytes = archive.to_bytes()

  // Decode and extract
  let decoded = Archive::of_bytes(zip_bytes)
  guard decoded.find("test.txt") is Some(found) else {
    fail("File should exist")
  }
  guard found.kind() is File(f) else { fail("Should be a file") }

  // Decompress - errors are catchable with try?
  let result = try? f.to_bytes()
  @json.inspect(result is Ok(_), content=true)
}
```

### Direct DEFLATE Compression/Decompression

```moonbit
///|
test "direct_deflate_usage" {
  // Create data to compress
  let buf = @buffer.ByteBuf::new(320, false)
  for i = 0; i < 20; i = i + 1 {
    buf.add_bytes(b"Hello, DEFLATE! ", 0, 16)
  }
  let original = buf.contents()

  // Compress with DEFLATE
  let compressed = @deflate.deflate(
    original,
    0,
    original.length(),
    level=@deflate.DeflateLevel::Default,
  )

  // Decompress
  let decompressed = @deflate.inflate(
    compressed,
    0,
    compressed.length(),
    Some(original.length()),
  )

  // Verify roundtrip
  @json.inspect(decompressed == original, content=true)

  // Check compression ratio
  let ratio = compressed.length() * 100 / original.length()
  @json.inspect(ratio < 50, content=true) // Should compress well
}
```

### API Pattern

1. **Create file data**: `File::deflate_of_bytes(bytes, start, len, level?)`
2. **Create member**: `Member::make(name, kind, mod_time?, comment?)`
3. **Build archive**: `Archive::empty().add(member1).add(member2)...`
4. **Encode**: `archive.to_bytes(comment?)`
5. **Decode**: `Archive::of_bytes(bytes)`
6. **Extract**: `archive.find(name)` or iterate with `members_iter()`
7. **Decompress**: `file.to_bytes()` (with automatic CRC verification)

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

