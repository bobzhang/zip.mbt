// zipc - ZIP archive and deflate codec for MoonBit
// Ported from OCaml zipc library
// Original: Copyright (c) 2023 The zipc programmers
// SPDX-License-Identifier: ISC

///|

///|
/// Helper: UInt to hex string
// fn UInt::to_hex_string(self : UInt) -> String {
//   let hex_digits = [
//     '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
//   ]
//   let mut result = ""
//   let v = self
//   for i = 0; i < 8; i = i + 1 {
//     let digit = ((v >> (28 - i * 4)) & (0xF : UInt)).reinterpret_as_int()
//     result = result + Char::to_string(hex_digits[digit])
//   }
//   result
// }

///|
/// Deflate format constants and symbols (RFC 1951)

// Literal/length symbols

///|
// let litlen_sym_max : Int = 285

///|
// let max_litlen_sym_count : Int = 286

///|
// let litlen_end_of_block_sym : Int = 256

///|
// let litlen_first_len_sym : Int = 257

///|
/// Extract base length value (upper bits)
// fn length_value_base(v : Int) -> Int {
//  v >> 4
//}

///|
/// Extract extra bits count (lower bits)
// fn length_value_extra_bits(v : Int) -> Int {
//  v & 0xF
//}

///|
/// Length value table from RFC 1951 3.2.5
/// Each entry packs (base_length << 4) | extra_bits
let length_value_of_sym_table : Array[Int] = [
  // Symbol 257-264: lengths 3-10, 0 extra bits
  3 << 4,
  4 << 4,
  5 << 4,
  6 << 4,
  7 << 4,
  8 << 4,
  9 << 4,
  10 << 4,
  // Symbol 265-268: lengths 11-17, 1 extra bit
  (11 << 4) | 1,
  (13 << 4) | 1,
  (15 << 4) | 1,
  (17 << 4) | 1,
  // Symbol 269-272: lengths 19-31, 2 extra bits
  (19 << 4) | 2,
  (23 << 4) | 2,
  (27 << 4) | 2,
  (31 << 4) | 2,
  // Symbol 273-276: lengths 35-59, 3 extra bits
  (35 << 4) | 3,
  (43 << 4) | 3,
  (51 << 4) | 3,
  (59 << 4) | 3,
  // Symbol 277-280: lengths 67-115, 4 extra bits
  (67 << 4) | 4,
  (83 << 4) | 4,
  (99 << 4) | 4,
  (115 << 4) | 4,
  // Symbol 281-284: lengths 131-227, 5 extra bits
  (131 << 4) | 5,
  (163 << 4) | 5,
  (195 << 4) | 5,
  (227 << 4) | 5,
  // Symbol 285: length 258, 0 extra bits
  258 << 4,
]

///|
test "length_value_table" {
  // Test a few entries from the length value table
  // Symbol 257 -> length 3, 0 extra bits
  @json.inspect(length_value_of_sym_table[0], content=48) // 3 << 4
  // Symbol 265 -> length 11, 1 extra bit
  @json.inspect(length_value_of_sym_table[8], content=177) // (11 << 4) | 1
  // Symbol 285 -> length 258, 0 extra bits
  @json.inspect(length_value_of_sym_table[28], content=4128) // 258 << 4
}

///|
// fn length_value_of_length_sym(sym : Int) -> Int {
//  length_value_of_sym_table[sym - litlen_first_len_sym]
//}

// Distance symbols

///|
// let dist_sym_max : Int = 29

///|
// let max_dist_sym_count : Int = 30

///|
// fn dist_value_base(v : Int) -> Int {
//  v >> 4
//}

///|
// fn dist_value_extra_bits(v : Int) -> Int {
//  v & 0xF
//}

///|
/// Distance value table from RFC 1951 3.2.5
let dist_value_of_sym : Array[Int] = [
  // Symbols 0-3: distances 1-4, 0 extra bits
  1 << 4,
  2 << 4,
  3 << 4,
  4 << 4,
  // Symbols 4-5: distances 5-7, 1 extra bit
  (5 << 4) | 1,
  (7 << 4) | 1,
  // Symbols 6-7: distances 9-13, 2 extra bits
  (9 << 4) | 2,
  (13 << 4) | 2,
  // Symbols 8-9: distances 17-25, 3 extra bits
  (17 << 4) | 3,
  (25 << 4) | 3,
  // Symbols 10-11: distances 33-49, 4 extra bits
  (33 << 4) | 4,
  (49 << 4) | 4,
  // Symbols 12-13: distances 65-97, 5 extra bits
  (65 << 4) | 5,
  (97 << 4) | 5,
  // Symbols 14-15: distances 129-193, 6 extra bits
  (129 << 4) | 6,
  (193 << 4) | 6,
  // Symbols 16-17: distances 257-385, 7 extra bits
  (257 << 4) | 7,
  (385 << 4) | 7,
  // Symbols 18-19: distances 513-769, 8 extra bits
  (513 << 4) | 8,
  (769 << 4) | 8,
  // Symbols 20-21: distances 1025-1537, 9 extra bits
  (1025 << 4) | 9,
  (1537 << 4) | 9,
  // Symbols 22-23: distances 2049-3073, 10 extra bits
  (2049 << 4) | 10,
  (3073 << 4) | 10,
  // Symbols 24-25: distances 4097-6145, 11 extra bits
  (4097 << 4) | 11,
  (6145 << 4) | 11,
  // Symbols 26-27: distances 8193-12289, 12 extra bits
  (8193 << 4) | 12,
  (12289 << 4) | 12,
  // Symbols 28-29: distances 16385-24577, 13 extra bits
  (16385 << 4) | 13,
  (24577 << 4) | 13,
]

///|
test "distance_value_table" {
  // Test a few entries from the distance value table
  // Symbol 0 -> distance 1, 0 extra bits
  @json.inspect(dist_value_of_sym[0], content=16) // 1 << 4
  // Symbol 4 -> distance 5, 1 extra bit
  @json.inspect(dist_value_of_sym[4], content=81) // (5 << 4) | 1
  // Symbol 29 -> distance 24577, 13 extra bits
  @json.inspect(dist_value_of_sym[29], content=393245) // (24577 << 4) | 13
}

// Code length symbols

///|
// let max_codelen_sym_count : Int = 19

///|
/// Order in which code length symbols are transmitted (RFC 1951 3.2.7)
// let codelen_order_of_sym_lengths : Array[Int] = [
//  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
// ]

///|
/// Huffman coding - Re-exported from huffman package
// typealias @huffman.(HuffmanDecoder, HuffmanEncoder, SymInfo)

///|
// let fixed_litlen_decoder : HuffmanDecoder = @huffman.fixed_litlen_decoder

///|
// let fixed_dist_decoder : HuffmanDecoder = @huffman.fixed_dist_decoder

///|
/// Compression - Re-exported from types package
typealias @types.Compression

///|
/// FileMode - File permission mode re-exported from types package
typealias @types.FileMode

///|
/// Ptime - POSIX time utilities re-exported from types package

///|
// pub let dos_epoch : @types.Ptime = @types.dos_epoch

// ============================================================================
// DEFLATE and zlib - Re-exported from deflate package
// ============================================================================

///|
/// File path utilities for ZIP archives

///|
/// File path type and utilities
/// Re-exports from types/fpath package
typealias @types.Fpath

///|
/// Convert string to UTF-8 bytes for ZIP encoding
fn string_to_utf8_bytes(s : String) -> Bytes {
  @encoding/utf8.encode(s)
}

///|
// ============================================================================
// File - Re-exported from file package
// ============================================================================

///|
typealias @file.File

///|
// ============================================================================
// Member - Re-exported from member package
// ============================================================================

///|
/// FIXME(upstream): find all references does not work
typealias @member.Member

///|
pub typealias @member.MemberKind

///|
// pub let max_member_count : Int = @member.max_member_count

///|
/// ZIP file format constants and detection

///|
/// ZIP local file header signature: 0x04034b50 ("PK\x03\x04")
// let zip_local_file_sig : Int = 0x04034b50

///|
/// ZIP local file header (little endian) ("PK\x03\x04")
const ZIP_LOCAL_FILE_SIG : UInt = 0x04034b50

///|
/// ZIP end of central directory signature (little endian) ("PK\x05\x06")
const ZIP_EOCD_SIG : UInt = 0x06054b50

///|
/// Check if bytes start with ZIP magic signature
fn bytes_has_zip_magic(data : Bytes) -> Bool {
  // FIXME(upstream): u4 should give a warning/error
  // when u4 has a literal pattern, what does it mean??
  // [u32(0x04034b50|0x06054b50),..] => true 
  data[:] is [u32le(ZIP_LOCAL_FILE_SIG | ZIP_EOCD_SIG), ..]
}

///|
/// ZIP magic detection tests
test "zip_magic_local_file_header" {
  // PK\x03\x04
  let data = Bytes::from_fixedarray([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00])
  @json.inspect(bytes_has_zip_magic(data), content=true)
}

///|
test "zip_magic_eocd" {
  // PK\x05\x06 (empty archive)
  let data = Bytes::from_fixedarray([0x50, 0x4B, 0x05, 0x06, 0x00, 0x00])
  @json.inspect(bytes_has_zip_magic(data), content=true)
}

///|
test "zip_magic_invalid" {
  let data = b"not a zip file"
  @json.inspect(bytes_has_zip_magic(data), content=false)
}

///|
test "zip_magic_too_short" {
  let data = Bytes::from_fixedarray([0x50, 0x4B])
  @json.inspect(bytes_has_zip_magic(data), content=false)
}

///|
test "archive_to_bytes_empty" {
  let archive = Archive::empty()
  let result = archive.to_bytes(None)
  match result {
    Ok(bytes) =>
      // Empty archive: just EOCD (22 bytes)
      @json.inspect((bytes.length(), bytes_has_zip_magic(bytes)), content=[
        22, true,
      ])
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_to_bytes_single_file" {
  let data = b"Hello ZIP!"
  let file = @file.File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = @member.make(@fpath.Fpath("hello.txt"), File(file), None, None).unwrap()
  let archive = Archive::empty().add(m)
  let result = archive.to_bytes(None)
  match result {
    Ok(bytes) =>
      @json.inspect((bytes.length() > 0, bytes_has_zip_magic(bytes)), content=[
        true, true,
      ])
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_to_bytes_directory" {
  let m = @member.make(@fpath.Fpath("mydir/"), Dir, None, None).unwrap()
  let archive = Archive::empty().add(m)
  let result = archive.to_bytes(None)
  match result {
    Ok(bytes) => @json.inspect(bytes_has_zip_magic(bytes), content=true)
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_to_bytes_multiple_files" {
  let data1 = b"file 1"
  let data2 = b"file 2"
  let file1 = @file.File::stored_of_bytes(data1, 0, data1.length()).unwrap()
  let file2 = @file.File::stored_of_bytes(data2, 0, data2.length()).unwrap()
  let m1 = @member.make(@fpath.Fpath("a.txt"), File(file1), None, None).unwrap()
  let m2 = @member.make(@fpath.Fpath("b.txt"), File(file2), None, None).unwrap()
  let archive = Archive::empty().add(m1).add(m2)
  let result = archive.to_bytes(None)
  match result {
    Ok(bytes) =>
      @json.inspect(
        (
          bytes.length() > 100,
          // 2 files
          bytes_has_zip_magic(bytes),
          archive.member_count(),
        ),
        content=[true, true, 2],
      )
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
/// ZIP file encoding utilities

///|
/// Helper to write 16-bit little-endian integer to array
fn write_uint16_le(arr : Array[Byte], pos : Int, value : UInt16) -> Unit {
  arr[pos] = (value & 0xFF).to_byte()
  arr[pos + 1] = ((value >> 8) & 0xFF).to_byte()
}

///|
/// Helper to write 32-bit little-endian integer to array
fn write_uint32_le(arr : Array[Byte], pos : Int, value : UInt) -> Unit {
  arr[pos] = (value & (0xFF : UInt)).reinterpret_as_int().to_byte()
  arr[pos + 1] = ((value >> 8) & (0xFF : UInt)).reinterpret_as_int().to_byte()
  arr[pos + 2] = ((value >> 16) & (0xFF : UInt)).reinterpret_as_int().to_byte()
  arr[pos + 3] = ((value >> 24) & (0xFF : UInt)).reinterpret_as_int().to_byte()
}

///|
/// Helper to write bytes to array
fn write_bytes(arr : Array[Byte], pos : Int, data : Bytes) -> Unit {
  for i = 0; i < data.length(); i = i + 1 {
    arr[pos + i] = data[i]
  }
}

///|
/// Central directory file header signature: 0x02014b50
let zip_central_dir_sig : Int = 0x02014b50

///|
/// ZIP file decoding utilities

///|
/// Helper to read 16-bit little-endian integer from bytes
fn read_uint16_le(data : Bytes, pos : Int) -> UInt16 {
  data[pos].to_uint16() | (data[pos + 1].to_uint16() << 8)
}

///|
/// Helper to read 32-bit little-endian integer from bytes
fn read_uint32_le(data : Bytes, pos : Int) -> UInt {
  let b0 = data[pos].to_int().reinterpret_as_uint()
  let b1 = data[pos + 1].to_int().reinterpret_as_uint()
  let b2 = data[pos + 2].to_int().reinterpret_as_uint()
  let b3 = data[pos + 3].to_int().reinterpret_as_uint()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
/// Find the end of central directory record (EOCD)
/// Returns the position of EOCD or None if not found
fn find_eocd(data : Bytes) -> Int? {
  let len = data.length()
  if len < 22 {
    return None // Too small to contain EOCD
  }

  // EOCD is at the end, search backwards
  // Maximum comment size is 65535, so search last 65557 bytes (22 + 65535)
  let search_start = if len > 65557 { len - 65557 } else { 0 }
  for i = len - 22; i >= search_start; i = i - 1 {
    let sig = read_uint32_le(data, i)
    if sig == ZIP_EOCD_SIG {
      return Some(i)
    }
  }
  None
}

///|
/// Parse end of central directory record
fn parse_eocd(data : Bytes, pos : Int) -> Result[(Int, Int, Int), String] {
  // Returns (central_dir_offset, central_dir_size, entry_count)
  if data.length() < pos + 22 {
    return Err("Truncated EOCD record")
  }
  let disk = read_uint16_le(data, pos + 4)
  let cd_disk = read_uint16_le(data, pos + 6)
  if disk != 0 || cd_disk != 0 {
    return Err("Multi-disk archives not supported")
  }
  let entries_this_disk = read_uint16_le(data, pos + 8).to_int()
  let entries_total = read_uint16_le(data, pos + 10).to_int()
  if entries_this_disk != entries_total {
    return Err("Inconsistent entry count in EOCD")
  }
  let cd_size = read_uint32_le(data, pos + 12).reinterpret_as_int()
  let cd_offset = read_uint32_le(data, pos + 16).reinterpret_as_int()
  Ok((cd_offset, cd_size, entries_total))
}

///|
/// Parse a central directory entry
fn parse_central_dir_entry(
  data : Bytes,
  pos : Int,
) -> Result[(Member, Int), String] {
  // Returns (member, next_position)
  if data.length() < pos + 46 {
    return Err("Truncated central directory entry")
  }
  let sig = read_uint32_le(data, pos)
  if sig != zip_central_dir_sig.to_int64().to_int().reinterpret_as_uint() {
    return Err("Invalid central directory signature")
  }
  let version_made_by = read_uint16_le(data, pos + 4)
  let version_needed = read_uint16_le(data, pos + 6)
  let gp_flags = read_uint16_le(data, pos + 8)
  let compression_method = read_uint16_le(data, pos + 10).to_int()
  let dos_time = read_uint16_le(data, pos + 12)
  let dos_date = read_uint16_le(data, pos + 14)
  let crc32 = read_uint32_le(data, pos + 16)
  let compressed_size = read_uint32_le(data, pos + 20).reinterpret_as_int()
  let uncompressed_size = read_uint32_le(data, pos + 24).reinterpret_as_int()
  let filename_len = read_uint16_le(data, pos + 28).to_int()
  let extra_len = read_uint16_le(data, pos + 30).to_int()
  let comment_len = read_uint16_le(data, pos + 32).to_int()
  let external_attrs = read_uint32_le(data, pos + 38)
  let local_header_offset = read_uint32_le(data, pos + 42).reinterpret_as_int()

  // Read filename
  if data.length() < pos + 46 + filename_len {
    return Err("Truncated filename in central directory")
  }
  let filename_arr = Array::make(filename_len, b'\x00')
  for i = 0; i < filename_len; i = i + 1 {
    filename_arr[i] = data[pos + 46 + i]
  }
  let filename_bytes = Bytes::from_fixedarray(
    FixedArray::from_iter(filename_arr[0:].iter()),
  )
  // Convert UTF-8 bytes to string - decode returns String, throws on error
  let path_str = @encoding/utf8.decode(filename_bytes) catch {
    _ => return Err("Failed to decode UTF-8 filename")
  }
  let path = @fpath.Fpath(path_str)

  // Calculate next position
  let next_pos = pos + 46 + filename_len + extra_len + comment_len

  // Determine if directory (path ends with /)
  let is_dir = path.length() > 0 && path[path.length() - 1] == '/'

  // Extract file mode from external attributes (Unix: high 16 bits)
  let mode = (external_attrs >> 16).reinterpret_as_int() & 0xFFFF
  let file_mode = if mode == 0 {
    if is_dir {
      @types.FileMode(0o755)
    } else {
      @types.FileMode(0o644)
    }
  } else {
    @types.FileMode(mode)
  }

  // Convert DOS time to POSIX time
  let mtime = @types.ptime_of_dos_date_time(dos_date, dos_time)

  // Parse local file header to get actual data offset
  if data.length() < local_header_offset + 30 {
    return Err("Invalid local header offset")
  }
  let local_sig = read_uint32_le(data, local_header_offset)
  if local_sig != ZIP_LOCAL_FILE_SIG {
    return Err("Invalid local file header signature")
  }
  let local_filename_len = read_uint16_le(data, local_header_offset + 26).to_int()
  let local_extra_len = read_uint16_le(data, local_header_offset + 28).to_int()
  let data_offset = local_header_offset +
    30 +
    local_filename_len +
    local_extra_len

  // Create member
  let kind = if is_dir {
    @member.Dir
  } else {
    let compression = Compression::from_int(compression_method)
    let file = match
      File::make(
        data,
        data_offset,
        compressed_size,
        compression,
        uncompressed_size,
        crc32,
        Some(version_made_by),
        Some(version_needed),
        Some(gp_flags),
      ) {
      Ok(f) => f
      Err(msg) => return Err(msg)
    }
    File(file)
  }
  let m = match @member.make(path, kind, Some(file_mode), Some(mtime)) {
    Ok(mem) => mem
    Err(msg) => return Err(msg)
  }
  Ok((m, next_pos))
}

///|
/// Decode ZIP archive from bytes
pub fn Archive::of_bytes(data : Bytes) -> Result[Archive, String] {
  // Check magic
  if not(bytes_has_zip_magic(data)) {
    return Err("Not a ZIP file: missing magic signature")
  }

  // Find EOCD
  let eocd_pos = match find_eocd(data) {
    Some(pos) => pos
    None => return Err("Could not find end of central directory")
  }

  // Parse EOCD
  let (cd_offset, _cd_size, entry_count) = match parse_eocd(data, eocd_pos) {
    Ok(result) => result
    Err(msg) => return Err(msg)
  }

  // Parse central directory entries
  let mut archive = Archive::empty()
  let mut pos = cd_offset
  for _i = 0; _i < entry_count; _i = _i + 1 {
    match parse_central_dir_entry(data, pos) {
      Ok((m, next_pos)) => {
        // Add member (last one wins if duplicate paths)
        archive = archive.add(m)
        pos = next_pos
      }
      Err(msg) => return Err(msg)
    }
  }
  Ok(archive)
}

///|
/// Calculate the size needed to encode an archive
pub fn Archive::encoding_size(self : Archive) -> Int {
  let mut size = 0
  // For each member: local file header + data + central directory header
  self.members.each(fn(_path, m) {
    let path_bytes = m.path().length()
    match m.kind() {
      Dir =>
        // Local file header (30) + path + central directory header (46) + path
        size = size + 30 + path_bytes + 46 + path_bytes
      File(f) =>
        // Local file header (30) + path + data + central directory header (46) + path
        size = size + 30 + path_bytes + f.compressed_size + 46 + path_bytes
    }
  })
  // End of central directory record (22)
  size = size + 22
  size
}

///|
/// Encode archive to bytes
pub fn Archive::to_bytes(
  self : Archive,
  first : Fpath?,
) -> Result[Bytes, String] {
  // Check member count limit
  let count = self.member_count()
  if count > @member.max_member_count {
    return Err(
      "Archive has \{count} members, exceeds maximum \{@member.max_member_count}",
    )
  }
  let total_size = self.encoding_size()
  // Allocate slightly more space to account for any rounding
  let result = Array::make(total_size + 1024, b'\x00')
  let mut pos = 0
  let central_dir_entries : Array[(Int, Member)] = []

  // Helper to encode a member
  let encode_member = fn(m : Member) {
    let path_bytes = string_to_utf8_bytes(m.path().to_string())
    let path_len = path_bytes.length()
    let (dos_date, dos_time) = @types.ptime_to_dos_date_time(m.mtime())
    match m.kind() {
      Dir => {
        // Local file header for directory
        write_uint32_le(
          result,
          pos,
          ZIP_LOCAL_FILE_SIG,
          // zip_local_file_sig.to_int64().to_int().reinterpret_as_uint(),
        )
        pos = pos + 4
        write_uint16_le(result, pos, @file.version_needed_default) // version needed
        pos = pos + 2
        write_uint16_le(result, pos, @file.gp_flag_default) // gp flags
        pos = pos + 2
        write_uint16_le(result, pos, 0) // compression method (stored)
        pos = pos + 2
        write_uint16_le(result, pos, dos_time) // last mod time
        pos = pos + 2
        write_uint16_le(result, pos, dos_date)
        pos = pos + 2
        write_uint32_le(result, pos, (0 : UInt)) // CRC-32
        pos = pos + 4
        write_uint32_le(result, pos, (0 : UInt)) // compressed size
        pos = pos + 4
        write_uint32_le(result, pos, (0 : UInt)) // uncompressed size
        pos = pos + 4
        write_uint16_le(result, pos, path_len.to_uint16()) // file name length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // extra field length
        pos = pos + 2
        write_bytes(result, pos, path_bytes)
        pos = pos + path_len
        central_dir_entries.push((pos - 30 - path_len, m))
      }
      File(f) => {
        // Record position for central directory
        let local_header_offset = pos

        // Local file header for file
        write_uint32_le(result, pos, ZIP_LOCAL_FILE_SIG)
        pos = pos + 4
        write_uint16_le(result, pos, f.version_needed_to_extract)
        pos = pos + 2
        write_uint16_le(result, pos, f.gp_flags)
        pos = pos + 2
        write_uint16_le(result, pos, f.compression.to_int().to_uint16())
        pos = pos + 2
        write_uint16_le(result, pos, dos_time)
        pos = pos + 2
        write_uint16_le(result, pos, dos_date)
        pos = pos + 2
        write_uint32_le(result, pos, f.decompressed_crc32)
        pos = pos + 4
        write_uint32_le(
          result,
          pos,
          f.compressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        pos = pos + 4
        write_uint32_le(
          result,
          pos,
          f.decompressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        pos = pos + 4
        write_uint16_le(result, pos, path_len.to_uint16())
        pos = pos + 2
        write_uint16_le(result, pos, 0) // extra field length
        pos = pos + 2
        write_bytes(result, pos, path_bytes)
        pos = pos + path_len

        // Write compressed data
        for i = 0; i < f.compressed_size; i = i + 1 {
          result[pos + i] = f.compressed_bytes[f.start + i]
        }
        pos = pos + f.compressed_size
        central_dir_entries.push((local_header_offset, m))
      }
    }
  }

  // Encode members in order (first, if specified, then rest in sorted order)
  match first {
    Some(first_path) =>
      match self.find(first_path) {
        Some(first_member) => {
          encode_member(first_member)
          // Encode rest in sorted order
          self.members.each(fn(path, m) {
            if path != first_path {
              encode_member(m)
            }
          })
        }
        None =>
          // First path not found, just encode all in sorted order
          self.members.each(fn(_path, m) { encode_member(m) })
      }
    None =>
      // Encode all in sorted order
      self.members.each(fn(_path, m) { encode_member(m) })
  }

  // Write central directory
  let central_dir_start = pos
  for entry in central_dir_entries {
    let (offset, m) = entry
    let path_bytes = string_to_utf8_bytes(m.path().to_string())
    let path_len = path_bytes.length()
    let (dos_date, dos_time) = @types.ptime_to_dos_date_time(m.mtime())
    write_uint32_le(
      result,
      pos,
      zip_central_dir_sig.to_int64().to_int().reinterpret_as_uint(),
    )
    pos = pos + 4
    match m.kind() {
      Dir => {
        write_uint16_le(result, pos, @file.version_made_by_default)
        pos = pos + 2
        write_uint16_le(result, pos, @file.version_needed_default)
        pos = pos + 2
        write_uint16_le(result, pos, @file.gp_flag_default)
        pos = pos + 2
        write_uint16_le(result, pos, 0) // compression
        pos = pos + 2
        write_uint16_le(result, pos, dos_time)
        pos = pos + 2
        write_uint16_le(result, pos, dos_date)
        pos = pos + 2
        write_uint32_le(result, pos, (0 : UInt)) // CRC
        pos = pos + 4
        write_uint32_le(result, pos, (0 : UInt)) // compressed size
        pos = pos + 4
        write_uint32_le(result, pos, (0 : UInt)) // uncompressed size
        pos = pos + 4
        write_uint16_le(result, pos, path_len.to_uint16()) // file name length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // extra field length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // file comment length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // disk number start
        pos = pos + 2
        write_uint16_le(result, pos, 0) // internal file attributes
        pos = pos + 2
        write_uint32_le(
          result,
          pos,
          (m.mode().to_int() << 16).to_int64().to_int().reinterpret_as_uint(),
        ) // external file attributes
        pos = pos + 4
        write_uint32_le(
          result,
          pos,
          offset.to_int64().to_int().reinterpret_as_uint(),
        ) // relative offset
        pos = pos + 4
        write_bytes(result, pos, path_bytes)
        pos = pos + path_len
      }
      File(f) => {
        write_uint16_le(result, pos, f.version_made_by)
        pos = pos + 2
        write_uint16_le(result, pos, f.version_needed_to_extract)
        pos = pos + 2
        write_uint16_le(result, pos, f.gp_flags)
        pos = pos + 2
        write_uint16_le(result, pos, f.compression.to_int().to_uint16())
        pos = pos + 2
        write_uint16_le(result, pos, dos_time)
        pos = pos + 2
        write_uint16_le(result, pos, dos_date)
        pos = pos + 2
        write_uint32_le(result, pos, f.decompressed_crc32)
        pos = pos + 4
        write_uint32_le(
          result,
          pos,
          f.compressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        pos = pos + 4
        write_uint32_le(
          result,
          pos,
          f.decompressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        pos = pos + 4
        write_uint16_le(result, pos, path_len.to_uint16())
        pos = pos + 2
        write_uint16_le(result, pos, 0) // extra field length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // file comment length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // disk number start
        pos = pos + 2
        write_uint16_le(result, pos, 0) // internal file attributes
        pos = pos + 2
        write_uint32_le(
          result,
          pos,
          (m.mode().to_int() << 16).to_int64().to_int().reinterpret_as_uint(),
        ) // external file attributes
        pos = pos + 4
        write_uint32_le(
          result,
          pos,
          offset.to_int64().to_int().reinterpret_as_uint(),
        ) // relative offset
        pos = pos + 4
        write_bytes(result, pos, path_bytes)
        pos = pos + path_len
      }
    }
  }
  let central_dir_size = pos - central_dir_start

  // Write end of central directory record
  write_uint32_le(result, pos, ZIP_EOCD_SIG)
  pos = pos + 4
  write_uint16_le(result, pos, 0) // disk number
  pos = pos + 2
  write_uint16_le(result, pos, 0) // disk with central directory
  pos = pos + 2
  write_uint16_le(result, pos, count.to_uint16()) // entries on this disk
  pos = pos + 2
  write_uint16_le(result, pos, count.to_uint16()) // total entries
  pos = pos + 2
  write_uint32_le(
    result,
    pos,
    central_dir_size.to_int64().to_int().reinterpret_as_uint(),
  )
  pos = pos + 4
  write_uint32_le(
    result,
    pos,
    central_dir_start.to_int64().to_int().reinterpret_as_uint(),
  )
  pos = pos + 4
  write_uint16_le(result, pos, 0) // comment length
  pos = pos + 2
  Ok(Bytes::from_fixedarray(FixedArray::from_iter(result[0:pos].iter())))
}

///|
/// Write archive bytes to a pre-allocated buffer at given offset
/// Returns the number of bytes written or error if buffer is too small
/// Note: Currently not implemented due to Bytes immutability - use to_bytes() instead
pub fn Archive::write_bytes(
  self : Archive,
  _buffer : Bytes,
  offset : Int,
  first : Fpath?,
) -> Result[Int, String] {
  match self.to_bytes(first) {
    Ok(encoded) => {
      let size = encoded.length()
      // Note: In MoonBit, Bytes is immutable so we can't write to it
      // This function exists for API compatibility but recommends using to_bytes()
      Err(
        "write_bytes not supported (Bytes is immutable): use to_bytes() instead. Would write \{size} bytes at offset \{offset}",
      )
    }
    Err(msg) => Err(msg)
  }
}
