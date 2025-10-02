# ZIP.MBT Package Architecture

## Overview

This document outlines the architecture for refactoring the monolithic `zip.mbt` library into smaller, well-organized packages. The refactoring will improve modularity, reusability, and maintainability while preserving all existing functionality and tests.

## Current State

**Single Package Structure:**
- `zip.mbt` (3,701 lines) - All functionality in one file
- `zip_test.mbt` (2,543 lines) - All unit tests
- `zip_e2e_test.mbt` (620 lines) - End-to-end integration tests
- `lz77_test.mbt` - LZ77 algorithm tests

**Total: 6,864 lines with 182 tests (162 passing)**

## Design Principles

1. **Dependency Hierarchy**: Packages are organized in layers, with leaf packages having zero dependencies on other project packages
2. **Single Responsibility**: Each package has a focused, well-defined purpose
3. **Test Preservation**: All existing tests will be kept and reorganized into appropriate packages
4. **API Stability**: Public APIs remain unchanged; only internal organization changes
5. **Incremental Migration**: Refactoring can be done incrementally, package by package

## Package Dependency Graph

```
Level 0 (Leaf Nodes - No Dependencies):
├── checksum/crc32      - CRC-32 checksum algorithm
└── checksum/adler32    - Adler-32 checksum algorithm

Level 1 (Low-level Utilities):
├── bitstream/reader    - Bit-level reading operations
├── bitstream/writer    - Bit-level writing operations
└── buffer/bytebuf      - Dynamic byte buffer

Level 2 (Codec Components):
├── huffman/decoder     - Huffman decoding (depends on bitstream/reader)
├── huffman/encoder     - Huffman encoding (depends on bitstream/writer)
└── lz77                - LZ77 string matching algorithm

Level 3 (Compression Formats):
├── deflate/decoder     - DEFLATE decompression (depends on huffman/decoder, buffer/bytebuf)
├── deflate/encoder     - DEFLATE compression (depends on huffman/encoder, lz77, buffer/bytebuf)
└── zlib                - zlib format wrapper (depends on deflate, checksum/adler32)

Level 4 (High-level Features):
├── filepath            - File path utilities and sanitization
├── dostime             - DOS date/time conversion (Ptime utilities)
└── filemode            - File mode/permissions formatting

Level 5 (ZIP Format):
├── zip/file            - ZIP file entry (File struct and operations)
└── zip/member          - ZIP archive member (Member struct)

Level 6 (Top Level):
└── zip/archive         - Complete ZIP archive operations (Archive struct)

Level 7 (Convenience API):
└── zip                 - High-level public API and re-exports
```

## Detailed Package Specifications

### Level 0: Checksums (Leaf Nodes)

#### Package: `checksum/crc32`

**Location**: `checksum/crc32/`

**Purpose**: CRC-32 checksum computation as defined in RFC 1952 (gzip)

**Dependencies**: None (stdlib only)

**Public API** (17 lines, ~6 functions):
```moonbit
pub struct Crc32 { value : UInt32 }

pub fn Crc32::init() -> Crc32
pub fn Crc32::finish(self : Crc32) -> UInt32
pub fn Crc32::update_byte(self : Crc32, byte : Int) -> Crc32
pub fn Crc32::update_bytes(self : Crc32, bytes : Bytes, start : Int, len : Int) -> Crc32
pub fn bytes_crc32(bytes : Bytes, start : Int, len : Int) -> UInt32
pub fn check_crc32(expect : UInt32, found : UInt32) -> Result[Unit, String]
```

**Implementation Size**: ~90 lines (including CRC32 table initialization)

**Tests to Migrate** (7 tests from `zip_test.mbt`):
- `test "crc32_empty"`
- `test "crc32_simple"`
- `test "crc32_incremental"`
- `test "crc32_check_success"`
- `test "crc32_check_failure"`
- Plus CRC32-related tests from E2E suite

**Files**:
```
checksum/crc32/
├── crc32.mbt          (~90 lines)
├── crc32_test.mbt     (~100 lines)
└── moon.pkg.json
```

---

#### Package: `checksum/adler32`

**Location**: `checksum/adler32/`

**Purpose**: Adler-32 checksum computation as defined in RFC 1950 (zlib)

**Dependencies**: None (stdlib only)

**Public API** (88-143 lines, ~5 functions):
```moonbit
pub struct Adler32 { s1 : UInt32, s2 : UInt32 }

pub fn Adler32::init() -> Adler32
pub fn Adler32::finish(self : Adler32) -> UInt32
pub fn Adler32::update_bytes(self : Adler32, bytes : Bytes, start : Int, len : Int) -> Adler32
pub fn bytes_adler32(bytes : Bytes, start : Int, len : Int) -> UInt32
pub fn check_adler32(expect : UInt32, found : UInt32) -> Result[Unit, String]
```

**Implementation Size**: ~60 lines

**Tests to Migrate** (6 tests from `zip_test.mbt`):
- `test "adler32_empty"`
- `test "adler32_simple"`
- `test "adler32_incremental"`
- Plus Adler32-related tests from E2E suite

**Files**:
```
checksum/adler32/
├── adler32.mbt        (~60 lines)
├── adler32_test.mbt   (~80 lines)
└── moon.pkg.json
```

---

### Level 1: Low-level Utilities

#### Package: `bitstream/reader`

**Location**: `bitstream/reader/`

**Purpose**: Bit-level reading from byte streams

**Dependencies**: None (stdlib only)

**Public API** (extracted from `InflateDecoder`):
```moonbit
pub struct BitReader {
  bytes : Bytes
  pos : Int         // Current byte position
  bit_buffer : Int  // Buffered bits
  bit_count : Int   // Number of bits in buffer
}

pub fn BitReader::new(bytes : Bytes, start : Int) -> BitReader
pub fn BitReader::read_bits(self : BitReader, count : Int) -> (BitReader, Int)
pub fn BitReader::read_int(self : BitReader, count : Int, signed : Bool) -> (BitReader, Int)
pub fn BitReader::align_to_byte(self : BitReader) -> BitReader
pub fn BitReader::position(self : BitReader) -> Int
```

**Implementation Size**: ~80 lines

**Tests to Migrate**: Extract bit-reading tests from inflate tests

**Files**:
```
bitstream/reader/
├── reader.mbt         (~80 lines)
├── reader_test.mbt    (~120 lines)
└── moon.pkg.json
```

---

#### Package: `bitstream/writer`

**Location**: `bitstream/writer/`

**Purpose**: Bit-level writing to byte streams

**Dependencies**: Depends on `buffer/bytebuf`

**Public API** (lines 1304-1360):
```moonbit
pub struct BitWriter {
  dst : ByteBuf
  bit_buffer : Int
  bit_count : Int
}

pub fn BitWriter::new(dst : ByteBuf) -> BitWriter
pub fn BitWriter::write_bits(self : BitWriter, value : Int, count : Int) -> Unit
pub fn BitWriter::flush(self : BitWriter) -> Unit
pub fn BitWriter::align_to_byte(self : BitWriter) -> Unit
pub fn BitWriter::write_byte(self : BitWriter, byte : Int) -> Unit
pub fn BitWriter::write_uint16_le(self : BitWriter, value : Int) -> Unit
```

**Implementation Size**: ~60 lines

**Tests to Migrate**: Extract bit-writing tests from deflate tests

**Files**:
```
bitstream/writer/
├── writer.mbt         (~60 lines)
├── writer_test.mbt    (~80 lines)
└── moon.pkg.json
```

---

#### Package: `buffer/bytebuf`

**Location**: `buffer/bytebuf/`

**Purpose**: Dynamic growable byte buffer for building byte sequences

**Dependencies**: None (stdlib only)

**Public API** (lines 389-490):
```moonbit
pub struct ByteBuf {
  bytes : Bytes        // Current buffer
  length : Int         // Number of bytes written
  fixed : Bool         // If true, don't grow
}

pub fn ByteBuf::new(size : Int, fixed : Bool) -> ByteBuf
pub fn ByteBuf::length(self : ByteBuf) -> Int
pub fn ByteBuf::contents(self : ByteBuf) -> Bytes
pub fn ByteBuf::add_byte(self : ByteBuf, byte : Int) -> Unit
pub fn ByteBuf::add_bytes(self : ByteBuf, bytes : Bytes, start : Int, len : Int) -> Unit
pub fn ByteBuf::recopy(self : ByteBuf, start : Int, len : Int) -> Unit
```

**Implementation Size**: ~100 lines

**Tests to Migrate** (5 tests from `zip_test.mbt`):
- `test "bytebuf_creation"`
- `test "bytebuf_add_byte"`
- `test "bytebuf_grow"`
- `test "bytebuf_recopy"`
- `test "bytebuf_recopy_overlapping"`

**Files**:
```
buffer/bytebuf/
├── bytebuf.mbt        (~100 lines)
├── bytebuf_test.mbt   (~120 lines)
└── moon.pkg.json
```

---

### Level 2: Codec Components

#### Package: `huffman/decoder`

**Location**: `huffman/decoder/`

**Purpose**: Huffman decoding for DEFLATE

**Dependencies**: 
- `bitstream/reader` (for bit-level reading)

**Public API** (lines 326-387):
```moonbit
pub struct HuffmanDecoder {
  lengths : Array[Int]     // Code lengths for each symbol
  codes : Array[Int]       // Huffman codes for each symbol
  first_code : Array[Int]  // First code for each length
  first_symbol : Array[Int] // First symbol for each length
  max_length : Int         // Maximum code length
}

pub fn HuffmanDecoder::new() -> HuffmanDecoder
pub fn HuffmanDecoder::init_from_lengths(
  self : HuffmanDecoder,
  lengths : Array[Int],
  count : Int
) -> Unit

pub fn read_symbol(
  decoder : HuffmanDecoder,
  reader : BitReader
) -> (BitReader, Int)
```

**Implementation Size**: ~150 lines

**Tests to Migrate** (3 tests from `zip_test.mbt`):
- `test "huffman_decoder_creation"`
- `test "fixed_litlen_decoder_setup"`
- `test "fixed_dist_decoder_setup"`
- Plus symbol reading tests

**Files**:
```
huffman/decoder/
├── decoder.mbt        (~150 lines)
├── decoder_test.mbt   (~180 lines)
└── moon.pkg.json
```

---

#### Package: `huffman/encoder`

**Location**: `huffman/encoder/`

**Purpose**: Huffman encoding for DEFLATE compression

**Dependencies**:
- `bitstream/writer` (for bit-level writing)

**Public API** (lines 1371-1803):
```moonbit
pub type SymInfo Int  // Packed: (code_length << 16) | code

pub fn sym_info_make(code : Int, code_length : Int) -> SymInfo
pub fn sym_info_code(info : SymInfo) -> Int
pub fn sym_info_code_length(info : SymInfo) -> Int

pub struct HuffmanEncoder {
  symbols : Array[SymInfo]  // Huffman codes for each symbol
}

pub fn HuffmanEncoder::new() -> HuffmanEncoder
pub fn HuffmanEncoder::get(self : HuffmanEncoder, symbol : Int) -> SymInfo
pub fn HuffmanEncoder::set(self : HuffmanEncoder, symbol : Int, info : SymInfo) -> Unit

// Optimal code length computation (Package-Merge algorithm)
pub fn build_optimal_code_lengths(
  frequencies : Array[Int],
  max_symbols : Int,
  max_length : Int
) -> Array[Int]

// Canonical Huffman code construction
pub fn build_canonical_huffman(
  code_lengths : Array[Int],
  max_symbols : Int
) -> HuffmanEncoder

// Code length encoding (for dynamic Huffman)
pub fn encode_code_lengths(
  litlen_lengths : Array[Int],
  dist_lengths : Array[Int],
  num_lit_codes : Int,
  num_dist_codes : Int
) -> (Array[Int], Int)

// Write dynamic Huffman header
pub fn write_dynamic_header(
  writer : BitWriter,
  litlen_encoder : HuffmanEncoder,
  dist_encoder : HuffmanEncoder,
  litlen_lengths : Array[Int],
  dist_lengths : Array[Int],
  num_lit_codes : Int,
  num_dist_codes : Int
) -> Unit

// Symbol writing helpers
pub fn length_to_symbol(length : Int) -> Int
pub fn distance_to_symbol(dist : Int) -> Int
pub fn write_literal_symbol(writer : BitWriter, encoder : HuffmanEncoder, lit : Int) -> Unit
pub fn write_length_distance(
  writer : BitWriter,
  litlen_encoder : HuffmanEncoder,
  dist_encoder : HuffmanEncoder,
  length : Int,
  dist : Int
) -> Unit
```

**Implementation Size**: ~430 lines

**Tests to Migrate**: Extract Huffman encoding tests from deflate tests

**Files**:
```
huffman/encoder/
├── encoder.mbt        (~430 lines)
├── encoder_test.mbt   (~200 lines)
└── moon.pkg.json
```

---

#### Package: `lz77`

**Location**: `lz77/`

**Purpose**: LZ77 string matching algorithm for compression

**Dependencies**: None (stdlib only)

**Public API** (lines 2007-2184):
```moonbit
// Hash table for string matching
pub fn hash4(bytes : Bytes, i : Int) -> Int
pub fn insert_hash(hash_head : Array[Int], hash_prev : Array[Int], hash : Int, pos : Int) -> Unit

// Match finding
pub fn match_fwd(bytes : Bytes, i : Int, j : Int, len : Int, max_match_len : Int) -> Int
pub fn find_match_length(
  bytes : Bytes,
  hash_head : Array[Int],
  hash_prev : Array[Int],
  pos : Int,
  max_match_len : Int
) -> Int

// Backref encoding
pub fn make_backref(dist : Int, len : Int) -> Int
pub fn backref_dist(bref : Int) -> Int
pub fn backref_len(bref : Int) -> Int

// Main LZ77 matching
pub fn find_backref(
  bytes : Bytes,
  start : Int,
  len : Int,
  good_match : Int,
  max_chain : Int
) -> Array[Int]  // Returns array of literals or backrefs
```

**Implementation Size**: ~180 lines

**Tests to Migrate**:
- All tests from `lz77_test.mbt` (if any)
- Extract LZ77-related tests from deflate tests

**Files**:
```
lz77/
├── lz77.mbt           (~180 lines)
├── lz77_test.mbt      (~150 lines)
└── moon.pkg.json
```

---

### Level 3: Compression Formats

#### Package: `deflate/decoder`

**Location**: `deflate/decoder/`

**Purpose**: DEFLATE decompression (RFC 1951)

**Dependencies**:
- `huffman/decoder` (for Huffman decoding)
- `bitstream/reader` (for bit-level reading)
- `buffer/bytebuf` (for output buffering)
- `checksum/crc32` (for inflate_and_crc32)
- `checksum/adler32` (for inflate_and_adler32)

**Public API** (lines 189-887):
```moonbit
// DEFLATE block type constants
pub let block_type_stored : Int = 0
pub let block_type_fixed : Int = 1
pub let block_type_dynamic : Int = 2

// Length/distance value tables
pub fn length_value_base(v : Int) -> Int
pub fn length_value_extra_bits(v : Int) -> Int
pub fn length_value_of_length_sym(sym : Int) -> Int
pub fn dist_value_base(v : Int) -> Int
pub fn dist_value_extra_bits(v : Int) -> Int

// Main decompression API
pub fn inflate(
  bytes : Bytes,
  start : Int,
  len : Int,
  known_size : Int?
) -> Bytes

pub fn inflate_and_crc32(
  bytes : Bytes,
  start : Int,
  len : Int,
  known_size : Int?
) -> (Bytes, UInt32)

pub fn inflate_and_adler32(
  bytes : Bytes,
  start : Int,
  len : Int,
  known_size : Int?
) -> (Bytes, UInt32)
```

**Implementation Size**: ~700 lines

**Tests to Migrate** (20+ tests from `zip_test.mbt`):
- `test "length_value_table"`
- `test "distance_value_table"`
- `test "inflate_uncompressed_block"`
- `test "inflate_with_crc32"`
- Plus all DEFLATE decompression tests from E2E suite

**Files**:
```
deflate/decoder/
├── decoder.mbt        (~700 lines)
├── decoder_test.mbt   (~400 lines)
└── moon.pkg.json
```

---

#### Package: `deflate/encoder`

**Location**: `deflate/encoder/`

**Purpose**: DEFLATE compression (RFC 1951)

**Dependencies**:
- `huffman/encoder` (for Huffman encoding)
- `bitstream/writer` (for bit-level writing)
- `buffer/bytebuf` (for output buffering)
- `lz77` (for string matching)

**Public API** (lines 1250-2570):
```moonbit
// Compression level
pub enum DeflateLevel {
  None      // No compression (stored blocks only)
  Fast      // Fast compression (fixed Huffman, minimal matching)
  Default   // Balanced compression (dynamic Huffman)
  Best      // Maximum compression (dynamic Huffman, extensive matching)
}

// Low-level compression functions
pub fn deflate_stored(bytes : Bytes, start : Int, len : Int) -> Bytes

pub fn deflate_fixed_literals_only(
  bytes : Bytes,
  start : Int,
  len : Int,
  final_block : Bool
) -> Bytes

pub fn deflate_fixed(
  bytes : Bytes,
  start : Int,
  len : Int,
  final_block : Bool,
  good_match : Int,
  max_chain : Int
) -> Bytes

pub fn deflate_dynamic(
  bytes : Bytes,
  start : Int,
  len : Int,
  final_block : Bool,
  good_match : Int,
  max_chain : Int
) -> Bytes

// High-level compression API
pub fn deflate(
  bytes : Bytes,
  start : Int,
  len : Int,
  level : DeflateLevel?
) -> Result[Bytes, String]

pub fn crc32_and_deflate(
  bytes : Bytes,
  start : Int,
  len : Int,
  level : DeflateLevel?
) -> Result[(UInt32, Bytes), String]

pub fn adler32_and_deflate(
  bytes : Bytes,
  start : Int,
  len : Int,
  level : DeflateLevel?
) -> Result[(UInt32, Bytes), String]
```

**Implementation Size**: ~1,320 lines

**Tests to Migrate**: Extract all DEFLATE compression tests from test suite

**Files**:
```
deflate/encoder/
├── encoder.mbt        (~1,320 lines)
├── encoder_test.mbt   (~500 lines)
└── moon.pkg.json
```

---

#### Package: `zlib`

**Location**: `zlib/`

**Purpose**: zlib format wrapper (RFC 1950)

**Dependencies**:
- `deflate/encoder` (for compression)
- `deflate/decoder` (for decompression)
- `checksum/adler32` (for checksums)
- `buffer/bytebuf` (for building output)

**Public API** (lines 2623-2762):
```moonbit
pub fn zlib_compress(
  bytes : Bytes,
  start : Int,
  len : Int,
  level : DeflateLevel?
) -> (UInt32, Bytes)

pub fn zlib_decompress(
  bytes : Bytes,
  start : Int,
  len : Int
) -> Result[(Bytes, UInt32), String]
```

**Implementation Size**: ~140 lines

**Tests to Migrate**: Extract zlib-specific tests from test suite

**Files**:
```
zlib/
├── zlib.mbt           (~140 lines)
├── zlib_test.mbt      (~150 lines)
└── moon.pkg.json
```

---

### Level 4: High-level Features

#### Package: `filepath`

**Location**: `filepath/`

**Purpose**: File path utilities and sanitization

**Dependencies**: None (stdlib only)

**Public API** (lines 890-970):
```moonbit
pub type Fpath = String

pub fn fpath_ensure_unix(path : Fpath) -> Fpath
pub fn fpath_ensure_directoryness(path : Fpath) -> Fpath
pub fn fpath_sanitize(path : Fpath) -> Fpath
```

**Implementation Size**: ~80 lines (including string_to_utf8_bytes helper)

**Tests to Migrate** (6 tests from `zip_test.mbt`):
- `test "fpath_ensure_unix"`
- `test "fpath_ensure_directoryness_empty"`
- `test "fpath_ensure_directoryness_no_slash"`
- `test "fpath_ensure_directoryness_has_slash"`
- `test "fpath_sanitize_basic"`
- `test "fpath_sanitize_removes_dots"`
- `test "fpath_sanitize_removes_empty"`
- `test "fpath_sanitize_mixed_slashes"`

**Files**:
```
filepath/
├── filepath.mbt       (~80 lines)
├── filepath_test.mbt  (~100 lines)
└── moon.pkg.json
```

---

#### Package: `dostime`

**Location**: `dostime/`

**Purpose**: DOS date/time conversion and formatting (Ptime utilities)

**Dependencies**: None (stdlib only)

**Public API** (lines 999-1126):
```moonbit
pub type Ptime = Int  // Unix timestamp in seconds

pub let dos_epoch : Ptime = 315532800  // 1980-01-01 00:00:00 UTC

pub fn ptime_to_date_time(ptime_s : Ptime) -> (Int, Int, Int, Int, Int, Int)
pub fn ptime_of_dos_date_time(dos_date : Int, dos_time : Int) -> Ptime
pub fn ptime_to_dos_date_time(ptime_s : Ptime) -> (Int, Int)
pub fn ptime_format(ptime : Ptime) -> String
```

**Implementation Size**: ~130 lines

**Tests to Migrate** (5 tests from `zip_test.mbt`):
- `test "ptime_dos_epoch"`
- `test "ptime_to_date_time"`
- `test "ptime_dos_roundtrip"`
- `test "ptime_format"`

**Files**:
```
dostime/
├── dostime.mbt        (~130 lines)
├── dostime_test.mbt   (~120 lines)
└── moon.pkg.json
```

---

#### Package: `filemode`

**Location**: `filemode/`

**Purpose**: File mode/permissions formatting

**Dependencies**: None (stdlib only)

**Public API** (lines 971-998):
```moonbit
pub type FileMode = Int

pub fn format_file_mode(mode : FileMode) -> String
```

**Implementation Size**: ~30 lines

**Tests to Migrate** (1 test from `zip_test.mbt`):
- `test "format_file_mode"`

**Files**:
```
filemode/
├── filemode.mbt       (~30 lines)
├── filemode_test.mbt  (~40 lines)
└── moon.pkg.json
```

---

### Level 5: ZIP Format

#### Package: `zip/file`

**Location**: `zip/file/`

**Purpose**: ZIP file entry representation and operations

**Dependencies**:
- `deflate/encoder` (for compression)
- `deflate/decoder` (for decompression)
- `checksum/crc32` (for checksums)

**Public API** (lines 1128-2622):
```moonbit
// Compression types
pub enum Compression {
  Stored   // No compression
  Deflate  // DEFLATE (RFC 1951)
  Bzip2    // Not implemented
  Lzma     // Not implemented
  Xz       // Not implemented
  Zstd     // Not implemented
  Other(Int) // Unknown method
}

pub fn Compression::to_int(self : Compression) -> Int
pub fn Compression::from_int(compression_method : Int) -> Compression
pub fn Compression::to_string(self : Compression) -> String

// File entry
pub struct File {
  compressed_bytes : Bytes
  start : Int
  compressed_size : Int
  compression : Compression
  decompressed_size : Int
  decompressed_crc32 : UInt32
  version_made_by : UInt16
  version_needed_to_extract : UInt16
  gp_flags : UInt16
}

// Construction
pub fn File::make(...) -> File
pub fn File::stored_of_bytes(...) -> File
pub fn File::deflate_of_bytes(...) -> File

// Accessors
pub fn File::compression(self : File) -> Compression
pub fn File::start(self : File) -> Int
pub fn File::compressed_size(self : File) -> Int
pub fn File::compressed_bytes(self : File) -> Bytes
pub fn File::compressed_bytes_to_bytes(self : File) -> Bytes
pub fn File::decompressed_size(self : File) -> Int
pub fn File::decompressed_crc32(self : File) -> UInt32
pub fn File::version_made_by(self : File) -> UInt16
pub fn File::version_needed_to_extract(self : File) -> UInt16
pub fn File::gp_flags(self : File) -> UInt16

// Operations
pub fn File::is_encrypted(self : File) -> Bool
pub fn File::can_extract(self : File) -> Bool
pub fn File::to_bytes_no_crc_check(self : File) -> (Bytes, UInt32)
pub fn File::to_bytes(self : File) -> Bytes
```

**Implementation Size**: ~500 lines

**Tests to Migrate** (5+ tests from `zip_test.mbt`):
- `test "compression_conversions"`
- `test "file_stored_simple"`
- `test "file_to_bytes_stored"`
- `test "file_is_encrypted"`
- Plus File-related tests from E2E suite

**Files**:
```
zip/file/
├── file.mbt           (~500 lines)
├── file_test.mbt      (~250 lines)
└── moon.pkg.json
```

---

#### Package: `zip/member`

**Location**: `zip/member/`

**Purpose**: ZIP archive member (file or directory entry)

**Dependencies**:
- `zip/file` (for File type)
- `filepath` (for path utilities)
- `dostime` (for time handling)
- `filemode` (for mode formatting)

**Public API** (lines 2875-3020):
```moonbit
pub enum MemberKind {
  Dir
  File(File)
}

pub let max_member_count : Int = 65535
pub let max_path_length : Int = 65535

pub struct Member {
  path : Fpath
  kind : MemberKind
  mode : FileMode
  mtime : Ptime
}

pub fn Member::make(...) -> Result[Member, String]
pub fn Member::path(self : Member) -> Fpath
pub fn Member::kind(self : Member) -> MemberKind
pub fn Member::mode(self : Member) -> FileMode
pub fn Member::mtime(self : Member) -> Ptime
pub fn Member::is_dir(self : Member) -> Bool
pub fn Member::is_file(self : Member) -> Bool
pub fn Member::format(self : Member) -> String
pub fn Member::format_long(self : Member) -> String
```

**Implementation Size**: ~150 lines

**Tests to Migrate** (7+ tests from `zip_test.mbt`):
- `test "member_make_file"`
- `test "member_make_dir"`
- `test "member_ensure_unix_path"`
- `test "member_default_mtime"`
- `test "member_custom_mode_and_mtime"`
- `test "member_format"`

**Files**:
```
zip/member/
├── member.mbt         (~150 lines)
├── member_test.mbt    (~180 lines)
└── moon.pkg.json
```

---

### Level 6: Top Level

#### Package: `zip/archive`

**Location**: `zip/archive/`

**Purpose**: Complete ZIP archive operations

**Dependencies**:
- `zip/member` (for Member type)
- `zip/file` (for File type)
- `buffer/bytebuf` (for building archives)
- `filepath` (for path handling)

**Public API** (lines 3021-3640):
```moonbit
pub struct Archive {
  members : @immut/sorted_map.SortedMap[String, Member]
}

// Construction
pub fn Archive::empty() -> Archive

// Queries
pub fn Archive::is_empty(self : Archive) -> Bool
pub fn Archive::member_count(self : Archive) -> Int
pub fn Archive::mem(self : Archive, path : Fpath) -> Bool
pub fn Archive::find(self : Archive, path : Fpath) -> Member?

// Modifications
pub fn Archive::add(self : Archive, m : Member) -> Archive
pub fn Archive::remove(self : Archive, path : Fpath) -> Archive

// Iteration
pub fn[T] Archive::fold(self : Archive, f : (Member, T) -> T, init : T) -> T
pub fn Archive::to_array(self : Archive) -> Array[Member]
pub fn Archive::to_map(self : Archive) -> @immut/sorted_map.SortedMap[String, Member]
pub fn Archive::of_map(map : @immut/sorted_map.SortedMap[String, Member]) -> Archive

// ZIP format I/O
pub fn bytes_has_zip_magic(data : Bytes) -> Bool
pub fn Archive::of_bytes(data : Bytes) -> Result[Archive, String]
pub fn Archive::to_bytes(self : Archive, first : Fpath?) -> Result[Bytes, String]
pub fn Archive::write_bytes(self : Archive, buffer : Bytes, offset : Int, first : Fpath?) -> Result[Int, String]
```

**Implementation Size**: ~620 lines

**Tests to Migrate** (20+ tests from `zip_test.mbt`):
- `test "archive_empty"`
- `test "archive_add_and_find"`
- `test "archive_find_member"`
- `test "archive_remove"`
- `test "archive_replace_member"`
- `test "archive_fold"`
- `test "zip_magic_local_file_header"`
- `test "zip_magic_eocd"`
- Plus all archive encoding/decoding tests from E2E suite

**Files**:
```
zip/archive/
├── archive.mbt        (~620 lines)
├── archive_test.mbt   (~400 lines)
└── moon.pkg.json
```

---

### Level 7: Convenience API

#### Package: `zip` (Top-level)

**Location**: Root package

**Purpose**: High-level public API and re-exports

**Dependencies**:
- All packages above

**Public API**: Re-exports all public APIs from subpackages

**Implementation Size**: ~50 lines (mostly re-exports and convenience functions)

**Tests**: 
- `zip_e2e_test.mbt` (11 end-to-end integration tests)

**Files**:
```
zip/
├── zip.mbt            (~50 lines of re-exports)
├── zip_e2e_test.mbt   (620 lines - keep as-is)
└── moon.pkg.json
```

---

## Migration Strategy

### Phase 1: Leaf Packages (Level 0)
**Order**: CRC32 → Adler32

**Steps**:
1. Create `checksum/crc32/` directory structure
2. Extract CRC32 code (lines 17-86) to `crc32.mbt`
3. Extract CRC32 tests to `crc32_test.mbt`
4. Create `moon.pkg.json` with no dependencies
5. Run tests to verify: `moon test checksum/crc32/`
6. Repeat for Adler32 (lines 88-152)

**Verification**: Both packages should compile and test independently

---

### Phase 2: Utilities (Level 1)
**Order**: ByteBuf → BitReader → BitWriter

**Steps for ByteBuf**:
1. Create `buffer/bytebuf/` directory
2. Extract ByteBuf code (lines 389-490)
3. Extract tests (5 tests)
4. Verify tests pass independently

**Steps for BitReader**:
1. Create `bitstream/reader/` directory
2. Extract bit-reading logic from `InflateDecoder`
3. Refactor `InflateDecoder` to use `BitReader`
4. Create tests
5. Verify both BitReader and updated inflate code work

**Steps for BitWriter**:
1. Create `bitstream/writer/` directory
2. Extract BitWriter code (lines 1304-1360)
3. Update to depend on `buffer/bytebuf`
4. Extract tests
5. Verify tests pass

---

### Phase 3: Codec Components (Level 2)
**Order**: Huffman Decoder → Huffman Encoder → LZ77

**Critical**: These packages require careful refactoring to maintain API compatibility

**Steps for Huffman Decoder**:
1. Create `huffman/decoder/` directory
2. Extract HuffmanDecoder code (lines 326-647)
3. Update to use `bitstream/reader`
4. Extract and adapt tests
5. Update `deflate/decoder` to depend on this package

**Steps for Huffman Encoder**:
1. Create `huffman/encoder/` directory
2. Extract encoder code (lines 1371-1803)
3. Update to use `bitstream/writer`
4. Extract tests
5. Update `deflate/encoder` to depend on this package

**Steps for LZ77**:
1. Create `lz77/` directory
2. Extract LZ77 code (lines 2007-2184)
3. Move `lz77_test.mbt` to this package
4. Verify all tests pass

---

### Phase 4: Compression Formats (Level 3)
**Order**: DEFLATE Decoder → DEFLATE Encoder → zlib

**Steps for DEFLATE Decoder**:
1. Create `deflate/decoder/` directory
2. Extract decompression code (lines 189-887)
3. Update dependencies to use new packages
4. Extract tests (20+ tests)
5. Verify inflate functionality

**Steps for DEFLATE Encoder**:
1. Create `deflate/encoder/` directory
2. Extract compression code (lines 1250-2570)
3. Update dependencies
4. Extract tests
5. Verify deflate functionality

**Steps for zlib**:
1. Create `zlib/` directory
2. Extract zlib wrapper code (lines 2623-2762)
3. Update to depend on deflate packages
4. Extract tests
5. Verify zlib compress/decompress

---

### Phase 5: High-level Features (Level 4)
**Order**: FileMode → FilePath → DOSTime

**These are simple utilities with minimal dependencies**

**Steps** (similar for each):
1. Create package directory
2. Extract code
3. Extract tests
4. Verify tests pass
5. Update dependent packages

---

### Phase 6: ZIP Format (Level 5 & 6)
**Order**: File → Member → Archive

**Steps for File**:
1. Create `zip/file/` directory
2. Extract File struct and operations (lines 1128-2622)
3. Update dependencies
4. Extract tests
5. Verify File operations

**Steps for Member**:
1. Create `zip/member/` directory
2. Extract Member code (lines 2875-3020)
3. Update to depend on `zip/file`
4. Extract tests
5. Verify Member operations

**Steps for Archive**:
1. Create `zip/archive/` directory
2. Extract Archive code (lines 3021-3640)
3. Update dependencies
4. Extract tests
5. Verify archive encode/decode

---

### Phase 7: Top-level API (Level 7)
**Order**: Final integration

**Steps**:
1. Create top-level `zip.mbt` with re-exports
2. Update `moon.pkg.json` to depend on all subpackages
3. Keep `zip_e2e_test.mbt` as integration tests
4. Run full test suite
5. Verify all 182 tests pass

---

## Testing Strategy

### Test Preservation Rules

1. **No Test Deletion**: All 182 tests must be preserved
2. **Test Organization**: Tests move with their corresponding code
3. **Integration Tests**: E2E tests remain at top level
4. **Test Independence**: Each package's tests must run independently

### Test Distribution

```
checksum/crc32/crc32_test.mbt           (~7 tests)
checksum/adler32/adler32_test.mbt       (~6 tests)
buffer/bytebuf/bytebuf_test.mbt         (~5 tests)
bitstream/reader/reader_test.mbt        (~10 tests)
bitstream/writer/writer_test.mbt        (~8 tests)
huffman/decoder/decoder_test.mbt        (~15 tests)
huffman/encoder/encoder_test.mbt        (~20 tests)
lz77/lz77_test.mbt                      (~10 tests)
deflate/decoder/decoder_test.mbt        (~25 tests)
deflate/encoder/encoder_test.mbt        (~30 tests)
zlib/zlib_test.mbt                      (~8 tests)
filepath/filepath_test.mbt              (~8 tests)
dostime/dostime_test.mbt                (~5 tests)
filemode/filemode_test.mbt              (~1 test)
zip/file/file_test.mbt                  (~8 tests)
zip/member/member_test.mbt              (~7 tests)
zip/archive/archive_test.mbt            (~20 tests)
zip/zip_e2e_test.mbt                    (~11 tests)

Total: ~204 tests (182 original + new tests for refactored interfaces)
```

### Verification Commands

```bash
# Test individual package
moon test checksum/crc32/

# Test all packages
moon test

# Test specific category
moon test checksum/
moon test deflate/

# Run E2E tests only
moon test zip_e2e_test.mbt
```

---

## Package Configuration

### moon.pkg.json Template (Leaf Package)

```json
{
  "name": "checksum/crc32",
  "version": "0.1.0",
  "description": "CRC-32 checksum computation (RFC 1952)",
  "license": "MIT",
  "authors": ["Original OCaml zipc authors", "MoonBit port team"],
  "test-import": []
}
```

### moon.pkg.json Template (Dependent Package)

```json
{
  "name": "deflate/decoder",
  "version": "0.1.0",
  "description": "DEFLATE decompression (RFC 1951)",
  "license": "MIT",
  "authors": ["Original OCaml zipc authors", "MoonBit port team"],
  "import": [
    "bobzhang/zip.mbt/checksum/crc32",
    "bobzhang/zip.mbt/checksum/adler32",
    "bobzhang/zip.mbt/huffman/decoder",
    "bobzhang/zip.mbt/bitstream/reader",
    "bobzhang/zip.mbt/buffer/bytebuf"
  ],
  "test-import": []
}
```

---

## Benefits of This Architecture

### 1. **Modularity**
- Each package has a single, well-defined responsibility
- Packages can be used independently (e.g., just CRC32 or just DEFLATE)

### 2. **Reusability**
- Checksum packages useful for any application
- DEFLATE codec can be used without ZIP format
- LZ77 can be reused for other compression formats

### 3. **Testability**
- Each package tested in isolation
- Easier to identify which component has issues
- Faster test execution for specific components

### 4. **Maintainability**
- Changes localized to specific packages
- Clear dependency boundaries prevent circular dependencies
- Easier to understand and modify individual components

### 5. **Documentation**
- Each package can have focused documentation
- API boundaries are clear and explicit
- Examples can be package-specific

### 6. **Performance**
- Smaller compilation units
- Potential for parallel compilation
- Easier to profile and optimize specific components

---

## Potential Challenges

### 1. **API Surface**
- **Challenge**: More packages means more APIs to maintain
- **Mitigation**: Keep internal APIs private where possible, only expose necessary functions

### 2. **Import Complexity**
- **Challenge**: More import statements needed
- **Mitigation**: Top-level `zip` package provides convenient re-exports

### 3. **Test Coordination**
- **Challenge**: Tests split across many files
- **Mitigation**: Maintain test count tracking, verify total coverage

### 4. **Refactoring Effort**
- **Challenge**: Significant work to split and test
- **Mitigation**: Incremental approach, level by level, with verification at each step

---

## Future Enhancements

After refactoring, these packages enable:

1. **Additional Compression Formats**
   - Bzip2 support (reuse LZ77 and Huffman)
   - Zstd support (reuse checksums and buffer utilities)

2. **Performance Optimization**
   - Profile and optimize specific packages
   - Add benchmarks per package

3. **Additional Features**
   - ZIP64 support (extend archive package)
   - Encryption support (extend file package)
   - Streaming API (extend decoder/encoder packages)

4. **Standalone Utilities**
   - Publish checksum packages separately
   - Publish DEFLATE codec independently
   - Create compression utilities library

---

## Summary

This architecture provides a clean, modular foundation for the ZIP library:

- **17 focused packages** organized in 7 dependency levels
- **Zero circular dependencies** - clear tree structure
- **All 182+ tests preserved** and reorganized
- **Incremental migration** possible with verification at each step
- **Enhanced reusability** - packages useful beyond just ZIP
- **Better maintainability** - easier to understand and modify

The refactoring will transform a monolithic 3,701-line file into a well-structured library of focused, reusable components while maintaining 100% feature compatibility.
