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
// typealias @types.Compression

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
fn String::utf8(s : String) -> Bytes {
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
/// ZIP file encoding utilities

///|
/// Central directory file header signature: 0x02014b50
// let zip_central_dir_sig : Int = 0x02014b50

///|
/// Central directory file header signature (little endian)
const ZIP_CENTRAL_DIR_SIG : UInt = 0x02014b50

///|
/// ZIP file decoding utilities

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
    if data[i:] is [u32le(ZIP_EOCD_SIG), ..] {
      return Some(i)
    }
  }
  None
}

///|
/// Parse end of central directory record
/// EOCD structure (22 bytes): signature(4) + disk(2) + cd_disk(2) + 
/// entries_this_disk(2) + entries_total(2) + cd_size(4) + cd_offset(4) + comment_len(2)
fn parse_eocd(data : Bytes, pos : Int) -> Result[(Int, Int, Int), String] {
  match data[pos + 4:] {
    [
      u16le(disk), // Disk number (multi-disk not supported)
      u16le(cd_disk), // Disk where central directory starts
      u16le(entries_this_disk), // Number of entries on this disk
      u16le(entries_total), // Total number of entries
      u32le(cd_size), // Size of central directory
      // Offset of start of central directory
      u32le(cd_offset),
      ..,
    ] => {
      if disk != 0 || cd_disk != 0 {
        return Err("Multi-disk archives not supported")
      }
      if entries_this_disk != entries_total {
        return Err("Inconsistent entry count in EOCD")
      }
      Ok(
        (
          cd_offset.reinterpret_as_int(),
          cd_size.reinterpret_as_int(),
          entries_total.reinterpret_as_int(),
        ),
      )
    }
    _ => Err("Truncated EOCD record")
  }
}

///|
/// Parse a central directory entry
/// Central directory structure (46 bytes fixed + variable): 
/// sig(4) + version_made_by(2) + version_needed(2) + gp_flags(2) + compression(2) +
/// dos_time(2) + dos_date(2) + crc32(4) + compressed_size(4) + uncompressed_size(4) +
/// filename_len(2) + extra_len(2) + comment_len(2) + disk_num(2) + internal_attrs(2) +
/// external_attrs(4) + local_header_offset(4) + filename + extra + comment
fn parse_central_dir_entry(
  data : Bytes,
  pos : Int,
) -> Result[(Member, Int), String] {
  // Returns (member, next_position)
  match data[pos:] {
    [
      u32le(sig), // Signature (0x02014b50)
      u16le(version_made_by), // Version made by
      u16le(version_needed), // Version needed to extract
      u16le(gp_flags), // General purpose bit flags
      u16le(compression_method), // Compression method
      u16le(dos_time), // Last mod file time (DOS format)
      u16le(dos_date), // Last mod file date (DOS format)
      u32le(crc32), // CRC-32 checksum
      u32le(compressed_size), // Compressed size
      u32le(uncompressed_size), // Uncompressed size
      u16le(filename_len), // Filename length
      u16le(extra_len), // Extra field length
      u16le(comment_len), // File comment length
      u16le(_disk_number_start), // Disk number where file starts
      u16le(_internal_attrs), // Internal file attributes
      u32le(external_attrs), // External file attributes (Unix permissions)
      // Offset of local file header
      u32le(local_header_offset),
      ..,
    ] => {
      if sig != ZIP_CENTRAL_DIR_SIG {
        return Err("Invalid central directory signature")
      }
      // Convert UInt to appropriate types
      let version_made_by : UInt16 = version_made_by
        .reinterpret_as_int()
        .to_uint16()
      let version_needed : UInt16 = version_needed
        .reinterpret_as_int()
        .to_uint16()
      let gp_flags : UInt16 = gp_flags.reinterpret_as_int().to_uint16()
      let compression_method = compression_method.reinterpret_as_int()
      let dos_time : UInt16 = dos_time.reinterpret_as_int().to_uint16()
      let dos_date : UInt16 = dos_date.reinterpret_as_int().to_uint16()
      let compressed_size = compressed_size.reinterpret_as_int()
      let uncompressed_size = uncompressed_size.reinterpret_as_int()
      let filename_len = filename_len.reinterpret_as_int()
      let extra_len = extra_len.reinterpret_as_int()
      let comment_len = comment_len.reinterpret_as_int()
      let local_header_offset = local_header_offset.reinterpret_as_int()

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
      // Local file header structure (30 bytes fixed + variable):
      // sig(4) + version_needed(2) + gp_flags(2) + compression(2) + dos_time(2) +
      // dos_date(2) + crc32(4) + compressed_size(4) + uncompressed_size(4) +
      // filename_len(2) + extra_len(2) + filename + extra + file_data
      let data_offset = match data[local_header_offset:] {
        [
          u32le(local_sig), // Signature (0x04034b50)
          u16le(_), // Version needed to extract
          u16le(_), // General purpose bit flags
          u16le(_), // Compression method
          u16le(_), // Last mod file time
          u16le(_), // Last mod file date
          u32le(_), // CRC-32 checksum
          u32le(_), // Compressed size
          u32le(_), // Uncompressed size
          u16le(local_filename_len), // Filename length
          // Extra field length
          u16le(local_extra_len),
          ..,
        ] => {
          if local_sig != ZIP_LOCAL_FILE_SIG {
            return Err("Invalid local file header signature")
          }
          let local_filename_len = local_filename_len.reinterpret_as_int()
          let local_extra_len = local_extra_len.reinterpret_as_int()
          local_header_offset + 30 + local_filename_len + local_extra_len
        }
        _ => return Err("Invalid local header offset")
      }

      // Create member
      let kind = if is_dir {
        @member.Dir
      } else {
        let compression = @types.compression(compression_method)
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
    _ => Err("Truncated central directory entry")
  }
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
