// zipc - ZIP archive and deflate codec for MoonBit
// Ported from OCaml zipc library
// Original: Copyright (c) 2023 The zipc programmers
// SPDX-License-Identifier: ISC

///|
/// Unsigned integer types
typealias Int as UInt16

///|
typealias Int64 as UInt32

///|
/// CRC-32 and Adler-32 checksums - Re-exported from checksum packages
pub typealias @crc32.Crc32 as Crc32
pub fn bytes_crc32(bytes : Bytes, start : Int, len : Int) -> UInt32 {
  @crc32.bytes_crc32(bytes, start, len)
}
pub fn check_crc32(expect : UInt32, found : UInt32) -> Result[Unit, String] {
  @crc32.check_crc32(expect, found)
}

pub typealias @adler32.Adler32 as Adler32
pub fn bytes_adler32(bytes : Bytes, start : Int, len : Int) -> UInt32 {
  @adler32.bytes_adler32(bytes, start, len)
}
pub fn check_adler32(expect : UInt32, found : UInt32) -> Result[Unit, String] {
  @adler32.check_adler32(expect, found)
}

///|
/// Helper: Int64 to hex string
fn Int64::to_hex_string(self : Int64) -> String {
  let hex_digits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let mut result = ""
  let v = self
  for i = 0; i < 8; i = i + 1 {
    let digit = (v >> (60 - i * 4)).land(0xFL).to_int()
    result = result + Char::to_string(hex_digits[digit])
  }
  result
}

///|
/// Deflate format constants and symbols (RFC 1951)

// Literal/length symbols

///|
let litlen_sym_max : Int = 285

///|
let max_litlen_sym_count : Int = 286

///|
let litlen_end_of_block_sym : Int = 256

///|
let litlen_first_len_sym : Int = 257

///|
/// Extract base length value (upper bits)
fn length_value_base(v : Int) -> Int {
  v >> 4
}

///|
/// Extract extra bits count (lower bits)
fn length_value_extra_bits(v : Int) -> Int {
  v & 0xF
}

///|
/// Length value table from RFC 1951 3.2.5
/// Each entry packs (base_length << 4) | extra_bits
pub let length_value_of_sym_table : Array[Int] = [
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
fn length_value_of_length_sym(sym : Int) -> Int {
  length_value_of_sym_table[sym - litlen_first_len_sym]
}

// Distance symbols

///|
let dist_sym_max : Int = 29

///|
let max_dist_sym_count : Int = 30

///|
fn dist_value_base(v : Int) -> Int {
  v >> 4
}

///|
fn dist_value_extra_bits(v : Int) -> Int {
  v & 0xF
}

///|
/// Distance value table from RFC 1951 3.2.5
pub let dist_value_of_sym : Array[Int] = [
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

// Code length symbols

///|
let max_codelen_sym_count : Int = 19

///|
/// Order in which code length symbols are transmitted (RFC 1951 3.2.7)
let codelen_order_of_sym_lengths : Array[Int] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
]

///|
/// Huffman coding - Re-exported from huffman package
pub typealias @huffman.HuffmanDecoder as HuffmanDecoder
pub typealias @huffman.HuffmanEncoder as HuffmanEncoder
pub typealias @huffman.SymInfo as SymInfo

let fixed_litlen_decoder : HuffmanDecoder = @huffman.fixed_litlen_decoder
let fixed_dist_decoder : HuffmanDecoder = @huffman.fixed_dist_decoder

///|
/// ByteBuf - Re-exported from buffer package
pub typealias @buffer.ByteBuf as ByteBuf

///|
/// BitWriter - Re-exported from bitstream package
pub typealias @bitstream.BitWriter as BitWriter

///|
/// Compression - Re-exported from types package
pub typealias @types.Compression as Compression

///|
/// Ptime - POSIX time utilities re-exported from types package
pub typealias @types.Ptime as Ptime
pub let dos_epoch : Ptime = @types.dos_epoch
pub fn ptime_to_date_time(ptime : Ptime) -> ((Int, Int, Int), (Int, Int, Int)) {
  @types.ptime_to_date_time(ptime)
}
pub fn ptime_of_dos_date_time(dos_date : Int, dos_time : Int) -> Ptime {
  @types.ptime_of_dos_date_time(dos_date, dos_time)
}
pub fn ptime_to_dos_date_time(ptime : Ptime) -> (Int, Int) {
  @types.ptime_to_dos_date_time(ptime)
}
pub fn ptime_format(ptime : Ptime) -> String {
  @types.ptime_format(ptime)
}

///|
/// Inflate decoder state
priv struct InflateDecoder {
  src : Bytes // Source compressed data
  src_max : Int // Maximum valid index in src
  mut src_pos : Int // Current read position
  mut src_bits : Int // Buffered bits (up to 31 bits)
  mut src_bits_len : Int // Number of valid bits in src_bits
  dst : ByteBuf // Output buffer
  dyn_litlen : HuffmanDecoder // Dynamic literal/length decoder
  dyn_dist : HuffmanDecoder // Dynamic distance decoder
}

///|
/// Create a new inflate decoder
fn InflateDecoder::new(
  src : Bytes,
  start : Int,
  len : Int,
  decompressed_size : Int?,
) -> InflateDecoder {
  let src_max = start + len - 1
  let dst = match decompressed_size {
    Some(size) => ByteBuf::new(size, true)
    None => ByteBuf::new(len * 3, false)
  }
  {
    src,
    src_max,
    src_pos: start,
    src_bits: 0,
    src_bits_len: 0,
    dst,
    dyn_litlen: HuffmanDecoder::new(),
    dyn_dist: HuffmanDecoder::new(),
  }
}

///|
/// Read N bits from the bit stream (N < 32)
fn InflateDecoder::read_bits(self : InflateDecoder, count : Int) -> Int {
  let mut bits = self.src_bits
  let mut bits_len = self.src_bits_len
  // Refill bit buffer if needed
  while bits_len < count {
    if self.src_pos > self.src_max {
      abort("Corrupted deflate stream: unexpected end of data")
    }
    let byte = self.src[self.src_pos].to_int()
    bits = bits | (byte << bits_len)
    self.src_pos = self.src_pos + 1
    bits_len = bits_len + 8
  }
  // Extract requested bits
  let result = bits & ((1 << count) - 1)
  self.src_bits = bits >> count
  self.src_bits_len = bits_len - count
  result
}

///|
/// Read an integer value: base + read_bits(bit_count)
fn InflateDecoder::read_int(
  self : InflateDecoder,
  base : Int,
  bit_count : Int,
) -> Int {
  if bit_count == 0 {
    base
  } else {
    base + self.read_bits(bit_count)
  }
}

///|
/// Read a symbol using a Huffman decoder (helper)
fn read_symbol_loop(
  decoder_state : InflateDecoder,
  decoder : HuffmanDecoder,
  len : Int,
  base : Int,
  offs : Int,
) -> Int {
  let new_offs = 2 * offs + decoder_state.read_bits(1)
  let count = decoder.counts[len]
  if new_offs < count {
    decoder.symbols[base + new_offs]
  } else {
    read_symbol_loop(
      decoder_state,
      decoder,
      len + 1,
      base + count,
      new_offs - count,
    )
  }
}

///|
/// Read a symbol using a Huffman decoder
fn InflateDecoder::read_symbol(
  self : InflateDecoder,
  decoder : HuffmanDecoder,
) -> Int {
  read_symbol_loop(self, decoder, 1, 0, 0)
}

///|
/// Read and process symbols from a compressed block
fn read_block_symbols(
  decoder : InflateDecoder,
  litlen_decoder : HuffmanDecoder,
  dist_decoder : HuffmanDecoder,
) -> Unit {
  while true {
    let sym = decoder.read_symbol(litlen_decoder)
    if sym < litlen_end_of_block_sym {
      // Literal byte
      decoder.dst.add_byte(sym)
    } else if sym == litlen_end_of_block_sym {
      // End of block
      return
    } else if sym > litlen_decoder.max_sym ||
      sym > litlen_sym_max ||
      litlen_decoder.max_sym == -1 {
      abort("Corrupted deflate stream: invalid literal/length symbol")
    } else {
      // Length symbol - read the length
      let len_value = length_value_of_length_sym(sym)
      let base = length_value_base(len_value)
      let extra_bits = length_value_extra_bits(len_value)
      let length = decoder.read_int(base, extra_bits)

      // Read the distance
      let dist_sym = decoder.read_symbol(dist_decoder)
      if dist_sym > dist_decoder.max_sym || dist_sym > dist_sym_max {
        abort("Corrupted deflate stream: invalid distance symbol")
      }
      let dist_value = dist_value_of_sym[dist_sym]
      let dist_base = dist_value_base(dist_value)
      let dist_extra = dist_value_extra_bits(dist_value)
      let dist = decoder.read_int(dist_base, dist_extra)

      // Copy from earlier in the output
      if dist > decoder.dst.length() {
        abort("Corrupted deflate stream: distance too large")
      }
      decoder.dst.recopy(decoder.dst.length() - dist, length)
    }
  }
}

///|
/// Read an uncompressed (stored) block
fn read_uncompressed_block(decoder : InflateDecoder) -> Unit {
  // Skip to byte boundary
  decoder.src_bits = 0
  decoder.src_bits_len = 0

  // Need at least 4 bytes for length fields
  if decoder.src_max - decoder.src_pos + 1 < 4 {
    abort("Corrupted deflate stream: truncated uncompressed block")
  }

  // Read length and inverted length
  let length = decoder.src[decoder.src_pos].to_int() |
    (decoder.src[decoder.src_pos + 1].to_int() << 8)
  let inv_length = decoder.src[decoder.src_pos + 2].to_int() |
    (decoder.src[decoder.src_pos + 3].to_int() << 8)
  decoder.src_pos = decoder.src_pos + 4

  // Verify they are complements
  if length != (inv_length ^ 0xFFFF) {
    abort("Corrupted deflate stream: invalid uncompressed block length")
  }

  // Check we have enough data
  if decoder.src_max - decoder.src_pos + 1 < length {
    abort("Corrupted deflate stream: truncated uncompressed block data")
  }

  // Copy bytes directly
  decoder.dst.add_bytes(decoder.src, decoder.src_pos, length)
  decoder.src_pos = decoder.src_pos + length
}

///|
/// Read a block compressed with fixed Huffman codes
fn read_fixed_block(decoder : InflateDecoder) -> Unit {
  read_block_symbols(decoder, fixed_litlen_decoder, fixed_dist_decoder)
}

///|
/// Read a block compressed with dynamic Huffman codes
fn read_dynamic_block(decoder : InflateDecoder) -> Unit {
  // Read number of literal/length codes (257-286)
  let hlit = decoder.read_int(257, 5)
  // Read number of distance codes (1-32)
  let hdist = decoder.read_int(1, 5)
  if hlit > max_litlen_sym_count || hdist > max_dist_sym_count {
    abort("Corrupted deflate stream: invalid dynamic block header")
  }

  // Read number of code length codes (4-19)
  let hclen = decoder.read_int(4, 4)

  // Read code length code lengths
  let codelen_lengths = Array::make(max_codelen_sym_count, 0)
  for i = 0; i < hclen; i = i + 1 {
    codelen_lengths[codelen_order_of_sym_lengths[i]] = decoder.read_bits(3)
  }

  // Build Huffman decoder for code lengths (temporarily use dyn_litlen)
  decoder.dyn_litlen.init_from_lengths(
    codelen_lengths, 0, max_codelen_sym_count,
  )
  if decoder.dyn_litlen.max_sym == -1 {
    abort("Corrupted deflate stream: empty code length code")
  }

  // Decode the literal/length and distance code lengths
  let lengths = Array::make(max_litlen_sym_count + max_dist_sym_count, 0)
  let mut num = 0
  let total = hlit + hdist
  while num < total {
    let sym = decoder.read_symbol(decoder.dyn_litlen)
    if sym > decoder.dyn_litlen.max_sym {
      abort("Corrupted deflate stream: invalid code length symbol")
    }
    let (repeat, value) = match sym {
      16 => {
        // Repeat previous code length 3-6 times
        if num == 0 {
          abort("Corrupted deflate stream: repeat with no previous code")
        }
        (decoder.read_int(3, 2), lengths[num - 1])
      }
      17 =>
        // Repeat zero 3-10 times
        (decoder.read_int(3, 3), 0)
      18 =>
        // Repeat zero 11-138 times  
        (decoder.read_int(11, 7), 0)
      _ => (1, sym)
    }
    if repeat > total - num {
      abort("Corrupted deflate stream: code length repeat too long")
    }
    for i = 0; i < repeat; i = i + 1 {
      lengths[num] = value
      num = num + 1
    }
  }

  // Check that end-of-block symbol has non-zero length
  if lengths[256] == 0 {
    abort("Corrupted deflate stream: missing end-of-block code")
  }

  // Initialize the literal/length and distance decoders
  decoder.dyn_litlen.init_from_lengths(lengths, 0, hlit)
  decoder.dyn_dist.init_from_lengths(lengths, hlit, hdist)

  // Decompress the block
  read_block_symbols(decoder, decoder.dyn_litlen, decoder.dyn_dist)
}

///|
/// Main inflate loop - decompress all blocks
fn inflate_loop(decoder : InflateDecoder) -> Bytes {
  while true {
    // Read block header
    let is_final = decoder.read_bits(1) == 1
    let btype = decoder.read_bits(2)

    // Process block based on type
    match btype {
      0 => read_uncompressed_block(decoder) // No compression
      1 => read_fixed_block(decoder) // Fixed Huffman
      2 => read_dynamic_block(decoder) // Dynamic Huffman
      _ => abort("Corrupted deflate stream: invalid block type")
    }
    if is_final {
      return decoder.dst.contents()
    }
  }
  // Unreachable
  abort("Unreachable")
}

///|
/// Decompress deflate format data (RFC 1951)
/// Returns the decompressed bytes
/// Aborts on corrupted data
pub fn inflate(
  src : Bytes,
  start : Int,
  len : Int,
  decompressed_size : Int?,
) -> Bytes {
  let decoder = InflateDecoder::new(src, start, len, decompressed_size)
  inflate_loop(decoder)
}

///|
/// Decompress deflate data and compute CRC-32
/// Returns (decompressed bytes, CRC-32 checksum)
/// Aborts on corrupted data
pub fn inflate_and_crc32(
  src : Bytes,
  start : Int,
  len : Int,
  decompressed_size : Int?,
) -> (Bytes, UInt32) {
  let decoder = InflateDecoder::new(src, start, len, decompressed_size)
  let result = inflate_loop(decoder)
  // Compute CRC-32 of the decompressed data
  let crc = bytes_crc32(result, 0, result.length())
  (result, crc)
}

///|
/// Decompress deflate data and compute Adler-32
/// Returns (decompressed bytes, Adler-32 checksum)
/// Aborts on corrupted data
pub fn inflate_and_adler32(
  src : Bytes,
  start : Int,
  len : Int,
  decompressed_size : Int?,
) -> (Bytes, UInt32) {
  let decoder = InflateDecoder::new(src, start, len, decompressed_size)
  let result = inflate_loop(decoder)
  // Compute Adler-32 of the decompressed data
  let adler = bytes_adler32(result, 0, result.length())
  (result, adler)
}

///|
/// File path utilities for ZIP archives

///|
/// File path type and utilities
/// Re-exports from types/fpath package
pub typealias @types.Fpath as Fpath

pub fn fpath_ensure_unix(path : Fpath) -> Fpath {
  @types.fpath_ensure_unix(path)
}

pub fn fpath_ensure_directoryness(path : Fpath) -> Fpath {
  @types.fpath_ensure_directoryness(path)
}

pub fn fpath_sanitize(path : Fpath) -> Fpath {
  @types.fpath_sanitize(path)
}

///|
/// Unix file mode (permission bits)
pub typealias Int as FileMode

///|
/// Convert string to UTF-8 bytes for ZIP encoding
fn string_to_utf8_bytes(s : String) -> Bytes {
  @encoding/utf8.encode(s)
}

///|
/// Format Unix file mode like ls -l (e.g., "rwxr-xr-x")
pub fn format_file_mode(mode : FileMode) -> String {
  fn format_entity(m : Int) -> String {
    let r = if (m & 0o4) != 0 { "r" } else { "-" }
    let w = if (m & 0o2) != 0 { "w" } else { "-" }
    let x = if (m & 0o1) != 0 { "x" } else { "-" }
    r + w + x
  }

  format_entity(mode >> 6) + format_entity(mode >> 3) + format_entity(mode)
}

///|
/// File data in a ZIP archive
pub struct File {
  version_made_by : UInt16
  version_needed_to_extract : UInt16
  gp_flags : UInt16
  compression : Compression
  start : Int // Start offset in compressed_bytes
  compressed_size : Int // Size in compressed_bytes
  compressed_bytes : Bytes // The actual compressed data
  decompressed_size : Int // Expected size when decompressed
  decompressed_crc32 : UInt32 // Expected CRC-32 of decompressed data
}

///|
/// Default values for ZIP file metadata
pub let gp_flag_encrypted : Int = 0x1

///|
pub let gp_flag_utf8 : Int = 0x800

///|
let gp_flag_default : Int = gp_flag_utf8

///|
let version_made_by_default : Int = (3 << 8) | 20 // UNIX + PKZIP 2.0

///|
let version_needed_default : Int = 20 // PKZIP 2.0

///|
/// Maximum file size in non-ZIP64 archives
pub let max_file_size : Int64 = 4294967295L // 2^32 - 1 (4GB)

///|
/// Create file data from compressed bytes
pub fn File::make(
  compressed_bytes : Bytes,
  start : Int,
  compressed_size : Int,
  compression : Compression,
  decompressed_size : Int,
  decompressed_crc32 : UInt32,
  version_made_by : Int?,
  version_needed : Int?,
  gp_flags : Int?,
) -> Result[File, String] {
  if compressed_size.to_int64() > max_file_size ||
    decompressed_size.to_int64() > max_file_size {
    Err(
      "Maximum ZIP file size \{max_file_size} exceeded: compressed=\{compressed_size}, decompressed=\{decompressed_size}",
    )
  } else {
    Ok({
      version_made_by: version_made_by.unwrap_or(version_made_by_default),
      version_needed_to_extract: version_needed.unwrap_or(
        version_needed_default,
      ),
      gp_flags: gp_flags.unwrap_or(gp_flag_default),
      compression,
      start,
      compressed_size,
      compressed_bytes,
      decompressed_size,
      decompressed_crc32,
    })
  }
}

///|
/// Create stored (uncompressed) file data from bytes
pub fn File::stored_of_bytes(
  bytes : Bytes,
  start : Int,
  len : Int,
) -> Result[File, String] {
  let crc = bytes_crc32(bytes, start, len)
  File::make(bytes, start, len, Compression::Stored, len, crc, None, None, None)
}

///|
/// Deflate compression levels
pub enum DeflateLevel {
  None // No compression, use stored blocks only
  Fast // Fast compression with fixed Huffman
  Default // Default compression with dynamic Huffman
  Best // Best compression with maximum effort
} derive(Eq, Show)

// ============================================================================
// Deflate Encoder (Compression) - Re-exported from deflate package
// ============================================================================

fn deflate_stored(bytes : Bytes, start : Int, len : Int) -> Bytes {
  @deflate.deflate_stored(bytes, start, len)
}

pub fn deflate_fixed_literals_only(
  bytes : Bytes,
  start : Int,
  len : Int,
  is_final : Bool,
) -> Bytes {
  @deflate.deflate_fixed_literals_only(bytes, start, len, is_final)
}

pub fn deflate_fixed(
  bytes : Bytes,
  start : Int,
  len : Int,
  is_final : Bool,
  good_match : Int,
  max_chain : Int
) -> Bytes {
  @deflate.deflate_fixed(bytes, start, len, is_final, good_match, max_chain)
}

pub fn deflate_dynamic(
  bytes : Bytes,
  start : Int,
  len : Int,
  is_final : Bool,
  good_match : Int,
  max_chain : Int
) -> Bytes {
  @deflate.deflate_dynamic(bytes, start, len, is_final, good_match, max_chain)
}

pub fn length_to_symbol(length : Int) -> Int {
  @deflate.length_to_symbol(length)
}

pub fn distance_to_symbol(dist : Int) -> Int {
  @deflate.distance_to_symbol(dist)
}

///|
/// Create deflate-compressed file data from bytes
/// Uses LZ77 + Huffman compression with optimal block type selection
pub fn File::deflate_of_bytes(
  bytes : Bytes,
  start : Int,
  len : Int,
  level : DeflateLevel?,
) -> Result[File, String] {
  // Determine compression parameters based on level
  let (good_match, max_chain, use_dynamic) = match level {
    Some(DeflateLevel::None) => {
      // No compression, use stored blocks
      let compressed = deflate_stored(bytes, start, len)
      let crc = bytes_crc32(bytes, start, len)
      return File::make(
        compressed,
        0,
        compressed.length(),
        Compression::Deflate,
        len,
        crc,
        None,
        None,
        None,
      )
    }
    Some(DeflateLevel::Fast) => (4, 128, false) // Fast: fixed Huffman only
    Some(DeflateLevel::Default) | None => (8, 1024, true) // Default: dynamic Huffman
    Some(DeflateLevel::Best) => (32, 4096, true) // Best: dynamic Huffman with max effort
  }
  
  // Choose between Fixed and Dynamic Huffman
  // Dynamic Huffman provides better compression but has header overhead
  // For small data (<256 bytes), fixed Huffman is often better
  let compressed = if use_dynamic && len >= 256 {
    // Use Dynamic Huffman for better compression on larger data
    deflate_dynamic(bytes, start, len, true, good_match, max_chain)
  } else {
    // Use Fixed Huffman for small data or Fast level
    deflate_fixed(bytes, start, len, true, good_match, max_chain)
  }
  
  let crc = bytes_crc32(bytes, start, len)
  File::make(
    compressed,
    0,
    compressed.length(),
    Compression::Deflate,
    len,
    crc,
    None,
    None,
    None,
  )
}

// ============================================================================
// zlib Wrapper Format (RFC 1950)
// ============================================================================

///|
/// Compress data with zlib wrapper format (RFC 1950)
/// Returns (Adler-32 checksum, compressed bytes)
///
/// zlib format:
/// - 2 bytes: CMF + FLG header
/// - N bytes: deflate compressed data
/// - 4 bytes: Adler-32 checksum (big-endian)
pub fn zlib_compress(
  bytes : Bytes,
  start : Int,
  len : Int,
  level : DeflateLevel?
) -> (UInt32, Bytes) {
  // Determine compression parameters
  let (good_match, max_chain, flevel) = match level {
    Some(DeflateLevel::None) => (4, 128, 0)
    Some(DeflateLevel::Fast) => (4, 128, 1)
    Some(DeflateLevel::Default) | None => (8, 1024, 2)
    Some(DeflateLevel::Best) => (32, 4096, 3)
  }
  
  let output = ByteBuf::new(len + 100, false)
  
  // Write CMF (Compression Method and Flags)
  // Bits 0-3: CM (compression method) = 8 for deflate
  // Bits 4-7: CINFO (window size) = 7 for 32KB window
  let cmf = (7 << 4).lor(8) // 0x78 = 120
  output.add_byte(cmf)
  
  // Write FLG (Flags)
  // Bits 0-4: FCHECK (check bits to make (CMF*256 + FLG) % 31 == 0)
  // Bit 5: FDICT = 0 (no preset dictionary)
  // Bits 6-7: FLEVEL (compression level)
  let flg_base = flevel << 6
  let header = (cmf << 8).lor(flg_base)
  let fcheck = (31 - header.mod(31)).mod(31)
  let flg = flg_base.lor(fcheck)
  output.add_byte(flg)
  
  // Write deflate compressed data
  let compressed = deflate_fixed(bytes, start, len, true, good_match, max_chain)
  for i = 0; i < compressed.length(); i = i + 1 {
    output.add_byte(compressed[i].to_int())
  }
  
  // Compute Adler-32 checksum of uncompressed data
  let adler = bytes_adler32(bytes, start, len)
  
  // Write Adler-32 checksum (big-endian, 4 bytes)
  let a32 = adler.to_int()
  output.add_byte((a32 >> 24).land(0xFF))
  output.add_byte((a32 >> 16).land(0xFF))
  output.add_byte((a32 >> 8).land(0xFF))
  output.add_byte(a32.land(0xFF))
  
  (adler, output.contents())
}

///|
/// Decompress zlib format data (RFC 1950)
/// Returns (decompressed bytes, Adler-32 checksum)
/// Validates header and checksum
pub fn zlib_decompress(
  bytes : Bytes,
  start : Int,
  len : Int
) -> Result[(Bytes, UInt32), String] {
  if len < 6 {
    return Err("zlib data too short (minimum 6 bytes)")
  }
  
  // Read and validate CMF
  let cmf = bytes[start].to_int()
  let cm = cmf.land(0x0F) // Compression method
  let cinfo = (cmf >> 4).land(0x0F) // Window size
  
  if cm != 8 {
    return Err("Invalid compression method (expected 8 for deflate)")
  }
  if cinfo > 7 {
    return Err("Invalid window size")
  }
  
  // Read and validate FLG
  let flg = bytes[start + 1].to_int()
  let _fcheck = flg.land(0x1F)
  let fdict = (flg >> 5).land(0x01)
  
  // Validate check bits
  let header = (cmf << 8).lor(flg)
  if header.mod(31) != 0 {
    return Err("Invalid zlib header checksum")
  }
  
  if fdict != 0 {
    return Err("Preset dictionary not supported")
  }
  
  // Decompress deflate data (skip 2-byte header, 4-byte trailer)
  let deflate_start = start + 2
  let deflate_len = len - 6
  let decompressed = inflate(bytes, deflate_start, deflate_len, None)
  
  // Read Adler-32 checksum (big-endian, last 4 bytes)
  let trailer_pos = start + len - 4
  let stored_adler = (bytes[trailer_pos].to_int() << 24)
    .lor(bytes[trailer_pos + 1].to_int() << 16)
    .lor(bytes[trailer_pos + 2].to_int() << 8)
    .lor(bytes[trailer_pos + 3].to_int())
  
  // Compute Adler-32 of decompressed data
  let computed_adler = bytes_adler32(decompressed, 0, decompressed.length())
  
  // Validate checksum
  if computed_adler.to_int() != stored_adler {
    return Err("Adler-32 checksum mismatch")
  }
  
  Ok((decompressed, computed_adler))
}

///|
/// Get compression format
pub fn File::compression(self : File) -> Compression {
  self.compression
}

///|
/// Get start offset in compressed_bytes
pub fn File::start(self : File) -> Int {
  self.start
}

///|
/// Get compressed size
pub fn File::compressed_size(self : File) -> Int {
  self.compressed_size
}

///|
/// Get compressed bytes (the full buffer)
pub fn File::compressed_bytes(self : File) -> Bytes {
  self.compressed_bytes
}

///|
/// Extract just the compressed data as a standalone Bytes object
pub fn File::compressed_bytes_to_bytes(self : File) -> Bytes {
  let result = Array::make(self.compressed_size, b'\x00')
  for i = 0; i < self.compressed_size; i = i + 1 {
    result[i] = self.compressed_bytes[self.start + i]
  }
  Bytes::from_fixedarray(FixedArray::from_iter(result[0:].iter()))
}

///|
/// Get decompressed size
pub fn File::decompressed_size(self : File) -> Int {
  self.decompressed_size
}

///|
/// Get decompressed CRC-32
pub fn File::decompressed_crc32(self : File) -> UInt32 {
  self.decompressed_crc32
}

///|
/// Get version made by
pub fn File::version_made_by(self : File) -> UInt16 {
  self.version_made_by
}

///|
/// Get version needed to extract
pub fn File::version_needed_to_extract(self : File) -> UInt16 {
  self.version_needed_to_extract
}

///|
/// Get general purpose flags
pub fn File::gp_flags(self : File) -> UInt16 {
  self.gp_flags
}

///|
/// Check if file is encrypted
pub fn File::is_encrypted(self : File) -> Bool {
  (self.gp_flags & gp_flag_encrypted) != 0
}

///|
/// Check if we can extract (decompress) this file
pub fn File::can_extract(self : File) -> Bool {
  if self.is_encrypted() {
    false
  } else {
    match self.compression {
      Stored | Deflate => true
      _ => false
    }
  }
}

///|
/// Decompress file data without CRC check
pub fn File::to_bytes_no_crc_check(self : File) -> (Bytes, UInt32) {
  if self.is_encrypted() {
    abort("Encrypted files are not supported")
  }
  match self.compression {
    Stored => {
      // Just extract the bytes, no decompression needed
      let result_arr = Array::make(self.compressed_size, b'\x00')
      for i = 0; i < self.compressed_size; i = i + 1 {
        result_arr[i] = self.compressed_bytes[self.start + i]
      }
      let result = Bytes::from_fixedarray(
        FixedArray::from_iter(result_arr[0:].iter()),
      )
      let crc = bytes_crc32(result, 0, result.length())
      (result, crc)
    }
    Deflate =>
      inflate_and_crc32(
        self.compressed_bytes,
        self.start,
        self.compressed_size,
        Some(self.decompressed_size),
      )
    _ => abort("Compression format \{self.compression} not supported")
  }
}

///|
/// Decompress file data with CRC check
pub fn File::to_bytes(self : File) -> Bytes {
  let (result, found_crc) = self.to_bytes_no_crc_check()
  let expected_crc = self.decompressed_crc32
  if found_crc != expected_crc {
    abort(
      "CRC-32 mismatch: expected \{expected_crc.to_hex_string()}, found \{found_crc.to_hex_string()}",
    )
  }
  result
}

///|
/// Archive Member - represents a file or directory in a ZIP archive
pub(all) enum MemberKind {
  Dir // Directory entry
  File(File) // File entry with compressed data
}

///|
/// Maximum number of members in a ZIP archive (non-ZIP64)
pub let max_member_count : Int = 65535

///|
/// Maximum path length in ZIP archives
pub let max_path_length : Int = 65535

///|
/// Archive member (file or directory)
pub struct Member {
  path : Fpath
  kind : MemberKind
  mode : FileMode
  mtime : Ptime
}

///|
/// Create a new archive member
pub fn Member::make(
  path : Fpath,
  kind : MemberKind,
  mode : FileMode?,
  mtime : Ptime?,
) -> Result[Member, String] {
  // Ensure Unix-style path
  let normalized_path = fpath_ensure_unix(path)

  // Ensure directories end with /
  let final_path = match kind {
    Dir => fpath_ensure_directoryness(normalized_path)
    File(_) => normalized_path
  }

  // Check path length
  if final_path.length() > max_path_length {
    Err("Path length \{final_path.length()} exceeds maximum \{max_path_length}")
  } else {
    // Set default mode
    let file_mode = mode.unwrap_or(
      match kind {
        Dir => 0o755
        File(_) => 0o644
      },
    )

    // Set default mtime (truncate to dos_epoch if before)
    let modification_time = mtime.unwrap_or(dos_epoch)
    let final_mtime = if modification_time < dos_epoch {
      dos_epoch
    } else {
      modification_time
    }
    Ok({ path: final_path, kind, mode: file_mode, mtime: final_mtime })
  }
}

///|
/// Get the path of a member
pub fn Member::path(self : Member) -> Fpath {
  self.path
}

///|
/// Get the kind of a member
pub fn Member::kind(self : Member) -> MemberKind {
  self.kind
}

///|
/// Get the file mode of a member
pub fn Member::mode(self : Member) -> FileMode {
  self.mode
}

///|
/// Get the modification time of a member
pub fn Member::mtime(self : Member) -> Ptime {
  self.mtime
}

///|
/// Check if member is a directory
pub fn Member::is_dir(self : Member) -> Bool {
  match self.kind {
    Dir => true
    File(_) => false
  }
}

///|
/// Check if member is a file
pub fn Member::is_file(self : Member) -> Bool {
  match self.kind {
    Dir => false
    File(_) => true
  }
}

///|
/// Format member info (like ls -l)
pub fn Member::format(self : Member) -> String {
  let is_dir_char = match self.kind {
    Dir => "d"
    File(_) => "-"
  }
  let mode_str = format_file_mode(self.mode)
  let size = match self.kind {
    Dir => 0
    File(f) => f.decompressed_size
  }
  let time_str = ptime_format(self.mtime)

  // Format size with padding (8 characters)
  let size_str = size.to_string()
  let spaces_needed = 8 - size_str.length()
  let mut padding = ""
  for i = 0; i < spaces_needed; i = i + 1 {
    padding = padding + " "
  }
  let padded_size = padding + size_str
  is_dir_char + mode_str + " " + padded_size + " " + time_str + " " + self.path
}

///|
/// Format member info with detailed compression information
pub fn Member::format_long(self : Member) -> String {
  let basic = self.format()
  match self.kind {
    Dir => basic
    File(f) => {
      let compression_str = f.compression.to_string()
      let ratio = if f.decompressed_size == 0 {
        "0%"
      } else {
        let pct = f.compressed_size * 100 / f.decompressed_size
        pct.to_string() + "%"
      }
      basic + " [" + compression_str + ", " + ratio + " compressed]"
    }
  }
}

///|
/// ZIP Archive - represents a complete ZIP file
pub struct Archive {
  members : @immut/sorted_map.SortedMap[String, Member] // Maps path to member
}

///|
/// Create an empty archive
pub fn Archive::empty() -> Archive {
  { members: @immut/sorted_map.SortedMap::new() }
}

///|
/// Check if archive is empty
pub fn Archive::is_empty(self : Archive) -> Bool {
  self.members.is_empty()
}

///|
/// Get the number of members in the archive
pub fn Archive::member_count(self : Archive) -> Int {
  let mut count = 0
  self.members.each(fn(_path, _m) { count = count + 1 })
  count
}

///|
/// Check if archive has a member with the given path
pub fn Archive::mem(self : Archive, path : Fpath) -> Bool {
  self.members.contains(path)
}

///|
/// Find a member by path
pub fn Archive::find(self : Archive, path : Fpath) -> Member? {
  self.members.get(path)
}

///|
/// Add a member to the archive (replaces if path already exists)
pub fn Archive::add(self : Archive, m : Member) -> Archive {
  { members: self.members.add(m.path(), m) }
}

///|
/// Remove a member from the archive by path
pub fn Archive::remove(self : Archive, path : Fpath) -> Archive {
  { members: self.members.remove(path) }
}

///|
/// Fold over all members in lexicographic path order
pub fn[T] Archive::fold(self : Archive, f : (Member, T) -> T, init : T) -> T {
  self.members.foldl_with_key(init~, fn(acc, _path, m) { f(m, acc) })
}

///|
/// Convert archive to an array of members (sorted by path)
pub fn Archive::to_array(self : Archive) -> Array[Member] {
  let result : Array[Member] = []
  self.members.each(fn(_path, m) { result.push(m) })
  result
}

///|
/// Convert archive to a SortedMap from path to member
pub fn Archive::to_map(
  self : Archive,
) -> @immut/sorted_map.SortedMap[String, Member] {
  self.members
}

///|
/// Create archive from a SortedMap
/// Warning: Assumes each key k maps to member m with Member::path(m) == k
pub fn Archive::of_map(
  map : @immut/sorted_map.SortedMap[String, Member],
) -> Archive {
  { members: map }
}

///|
/// ZIP file format constants and detection

///|
/// ZIP local file header signature: 0x04034b50 ("PK\x03\x04")
let zip_local_file_sig : Int = 0x04034b50

///|
/// ZIP end of central directory signature: 0x06054b50 ("PK\x05\x06")
let zip_eocd_sig : Int = 0x06054b50

///|
/// Check if bytes start with ZIP magic signature
pub fn bytes_has_zip_magic(data : Bytes) -> Bool {
  if data.length() < 4 {
    false
  } else {
    let sig = data[0].to_int() |
      (data[1].to_int() << 8) |
      (data[2].to_int() << 16) |
      (data[3].to_int() << 24)
    sig == zip_local_file_sig || sig == zip_eocd_sig
  }
}

///|
/// ZIP file encoding utilities

///|
/// Helper to write 16-bit little-endian integer to array
fn write_uint16_le(arr : Array[Byte], pos : Int, value : Int) -> Unit {
  arr[pos] = (value & 0xFF).to_byte()
  arr[pos + 1] = ((value >> 8) & 0xFF).to_byte()
}

///|
/// Helper to write 32-bit little-endian integer to array
fn write_uint32_le(arr : Array[Byte], pos : Int, value : Int64) -> Unit {
  arr[pos] = value.land(0xFFL).to_int().to_byte()
  arr[pos + 1] = (value >> 8).land(0xFFL).to_int().to_byte()
  arr[pos + 2] = (value >> 16).land(0xFFL).to_int().to_byte()
  arr[pos + 3] = (value >> 24).land(0xFFL).to_int().to_byte()
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
fn read_uint16_le(data : Bytes, pos : Int) -> Int {
  data[pos].to_int() | (data[pos + 1].to_int() << 8)
}

///|
/// Helper to read 32-bit little-endian integer from bytes
fn read_uint32_le(data : Bytes, pos : Int) -> Int64 {
  data[pos].to_int().to_int64() |
  (data[pos + 1].to_int().to_int64() << 8) |
  (data[pos + 2].to_int().to_int64() << 16) |
  (data[pos + 3].to_int().to_int64() << 24)
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
    if sig == zip_eocd_sig.to_int64() {
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
  let entries_this_disk = read_uint16_le(data, pos + 8)
  let entries_total = read_uint16_le(data, pos + 10)
  if entries_this_disk != entries_total {
    return Err("Inconsistent entry count in EOCD")
  }
  let cd_size = read_uint32_le(data, pos + 12).to_int()
  let cd_offset = read_uint32_le(data, pos + 16).to_int()
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
  if sig != zip_central_dir_sig.to_int64() {
    return Err("Invalid central directory signature")
  }
  let version_made_by = read_uint16_le(data, pos + 4)
  let version_needed = read_uint16_le(data, pos + 6)
  let gp_flags = read_uint16_le(data, pos + 8)
  let compression_method = read_uint16_le(data, pos + 10)
  let dos_time = read_uint16_le(data, pos + 12)
  let dos_date = read_uint16_le(data, pos + 14)
  let crc32 = read_uint32_le(data, pos + 16)
  let compressed_size = read_uint32_le(data, pos + 20).to_int()
  let uncompressed_size = read_uint32_le(data, pos + 24).to_int()
  let filename_len = read_uint16_le(data, pos + 28)
  let extra_len = read_uint16_le(data, pos + 30)
  let comment_len = read_uint16_le(data, pos + 32)
  let external_attrs = read_uint32_le(data, pos + 38)
  let local_header_offset = read_uint32_le(data, pos + 42).to_int()

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
  let path = try {
    @encoding/utf8.decode(filename_bytes)
  } catch {
    _ => return Err("Failed to decode UTF-8 filename")
  }

  // Calculate next position
  let next_pos = pos + 46 + filename_len + extra_len + comment_len

  // Determine if directory (path ends with /)
  let is_dir = path.length() > 0 && path[path.length() - 1] == '/'

  // Extract file mode from external attributes (Unix: high 16 bits)
  let mode = (external_attrs >> 16).to_int() & 0xFFFF
  let file_mode = if mode == 0 {
    if is_dir {
      0o755
    } else {
      0o644
    }
  } else {
    mode
  }

  // Convert DOS time to POSIX time
  let mtime = ptime_of_dos_date_time(dos_date, dos_time)

  // Parse local file header to get actual data offset
  if data.length() < local_header_offset + 30 {
    return Err("Invalid local header offset")
  }
  let local_sig = read_uint32_le(data, local_header_offset)
  if local_sig != zip_local_file_sig.to_int64() {
    return Err("Invalid local file header signature")
  }
  let local_filename_len = read_uint16_le(data, local_header_offset + 26)
  let local_extra_len = read_uint16_le(data, local_header_offset + 28)
  let data_offset = local_header_offset +
    30 +
    local_filename_len +
    local_extra_len

  // Create member
  let kind = if is_dir {
    MemberKind::Dir
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
    MemberKind::File(file)
  }
  let m = match Member::make(path, kind, Some(file_mode), Some(mtime)) {
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
  if count > max_member_count {
    return Err(
      "Archive has \{count} members, exceeds maximum \{max_member_count}",
    )
  }
  let total_size = self.encoding_size()
  // Allocate slightly more space to account for any rounding
  let result = Array::make(total_size + 1024, b'\x00')
  let mut pos = 0
  let central_dir_entries : Array[(Int, Member)] = []

  // Helper to encode a member
  let encode_member = fn(m : Member) {
    let path_bytes = string_to_utf8_bytes(m.path())
    let path_len = path_bytes.length()
    let (dos_date, dos_time) = ptime_to_dos_date_time(m.mtime())
    match m.kind() {
      Dir => {
        // Local file header for directory
        write_uint32_le(result, pos, zip_local_file_sig.to_int64())
        pos = pos + 4
        write_uint16_le(result, pos, version_needed_default) // version needed
        pos = pos + 2
        write_uint16_le(result, pos, gp_flag_default) // gp flags
        pos = pos + 2
        write_uint16_le(result, pos, 0) // compression method (stored)
        pos = pos + 2
        write_uint16_le(result, pos, dos_time)
        pos = pos + 2
        write_uint16_le(result, pos, dos_date)
        pos = pos + 2
        write_uint32_le(result, pos, 0L) // CRC-32
        pos = pos + 4
        write_uint32_le(result, pos, 0L) // compressed size
        pos = pos + 4
        write_uint32_le(result, pos, 0L) // uncompressed size
        pos = pos + 4
        write_uint16_le(result, pos, path_len) // file name length
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
        write_uint32_le(result, pos, zip_local_file_sig.to_int64())
        pos = pos + 4
        write_uint16_le(result, pos, f.version_needed_to_extract)
        pos = pos + 2
        write_uint16_le(result, pos, f.gp_flags)
        pos = pos + 2
        write_uint16_le(result, pos, f.compression.to_int())
        pos = pos + 2
        write_uint16_le(result, pos, dos_time)
        pos = pos + 2
        write_uint16_le(result, pos, dos_date)
        pos = pos + 2
        write_uint32_le(result, pos, f.decompressed_crc32)
        pos = pos + 4
        write_uint32_le(result, pos, f.compressed_size.to_int64())
        pos = pos + 4
        write_uint32_le(result, pos, f.decompressed_size.to_int64())
        pos = pos + 4
        write_uint16_le(result, pos, path_len)
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
    let path_bytes = string_to_utf8_bytes(m.path())
    let path_len = path_bytes.length()
    let (dos_date, dos_time) = ptime_to_dos_date_time(m.mtime())
    write_uint32_le(result, pos, zip_central_dir_sig.to_int64())
    pos = pos + 4
    match m.kind() {
      Dir => {
        write_uint16_le(result, pos, version_made_by_default)
        pos = pos + 2
        write_uint16_le(result, pos, version_needed_default)
        pos = pos + 2
        write_uint16_le(result, pos, gp_flag_default)
        pos = pos + 2
        write_uint16_le(result, pos, 0) // compression
        pos = pos + 2
        write_uint16_le(result, pos, dos_time)
        pos = pos + 2
        write_uint16_le(result, pos, dos_date)
        pos = pos + 2
        write_uint32_le(result, pos, 0L) // CRC
        pos = pos + 4
        write_uint32_le(result, pos, 0L) // compressed size
        pos = pos + 4
        write_uint32_le(result, pos, 0L) // uncompressed size
        pos = pos + 4
        write_uint16_le(result, pos, path_len)
        pos = pos + 2
        write_uint16_le(result, pos, 0) // extra field length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // file comment length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // disk number start
        pos = pos + 2
        write_uint16_le(result, pos, 0) // internal file attributes
        pos = pos + 2
        write_uint32_le(result, pos, (m.mode() << 16).to_int64()) // external file attributes
        pos = pos + 4
        write_uint32_le(result, pos, offset.to_int64()) // relative offset
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
        write_uint16_le(result, pos, f.compression.to_int())
        pos = pos + 2
        write_uint16_le(result, pos, dos_time)
        pos = pos + 2
        write_uint16_le(result, pos, dos_date)
        pos = pos + 2
        write_uint32_le(result, pos, f.decompressed_crc32)
        pos = pos + 4
        write_uint32_le(result, pos, f.compressed_size.to_int64())
        pos = pos + 4
        write_uint32_le(result, pos, f.decompressed_size.to_int64())
        pos = pos + 4
        write_uint16_le(result, pos, path_len)
        pos = pos + 2
        write_uint16_le(result, pos, 0) // extra field length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // file comment length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // disk number start
        pos = pos + 2
        write_uint16_le(result, pos, 0) // internal file attributes
        pos = pos + 2
        write_uint32_le(result, pos, (m.mode() << 16).to_int64()) // external file attributes
        pos = pos + 4
        write_uint32_le(result, pos, offset.to_int64()) // relative offset
        pos = pos + 4
        write_bytes(result, pos, path_bytes)
        pos = pos + path_len
      }
    }
  }
  let central_dir_size = pos - central_dir_start

  // Write end of central directory record
  write_uint32_le(result, pos, zip_eocd_sig.to_int64())
  pos = pos + 4
  write_uint16_le(result, pos, 0) // disk number
  pos = pos + 2
  write_uint16_le(result, pos, 0) // disk with central directory
  pos = pos + 2
  write_uint16_le(result, pos, count) // entries on this disk
  pos = pos + 2
  write_uint16_le(result, pos, count) // total entries
  pos = pos + 2
  write_uint32_le(result, pos, central_dir_size.to_int64())
  pos = pos + 4
  write_uint32_le(result, pos, central_dir_start.to_int64())
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

// ============================================================================
// High-level DEFLATE API Functions (for OCaml zipc compatibility)
// ============================================================================

///|
/// Compress data with DEFLATE format (RFC 1951)
/// Returns compressed bytes
pub fn deflate(
  bytes : Bytes,
  start : Int,
  len : Int,
  level : DeflateLevel?,
) -> Result[Bytes, String] {
  let (good_match, max_chain, use_dynamic) = match level {
    Some(DeflateLevel::None) => {
      // No compression, use stored blocks
      return Ok(deflate_stored(bytes, start, len))
    }
    Some(DeflateLevel::Fast) => (4, 128, false) // Fast: fixed Huffman only
    Some(DeflateLevel::Default) | None => (8, 1024, true) // Default: dynamic Huffman
    Some(DeflateLevel::Best) => (32, 4096, true) // Best: dynamic Huffman with max effort
  }
  
  // Choose between Fixed and Dynamic Huffman based on size and level
  let compressed = if use_dynamic && len >= 256 {
    deflate_dynamic(bytes, start, len, true, good_match, max_chain)
  } else {
    deflate_fixed(bytes, start, len, true, good_match, max_chain)
  }
  
  Ok(compressed)
}

///|
/// Compress data with DEFLATE and compute CRC-32 of input
/// Returns (CRC-32 checksum, compressed bytes)
pub fn crc32_and_deflate(
  bytes : Bytes,
  start : Int,
  len : Int,
  level : DeflateLevel?,
) -> Result[(UInt32, Bytes), String] {
  let crc = bytes_crc32(bytes, start, len)
  match deflate(bytes, start, len, level) {
    Ok(compressed) => Ok((crc, compressed))
    Err(msg) => Err(msg)
  }
}

///|
/// Compress data with DEFLATE and compute Adler-32 of input
/// Returns (Adler-32 checksum, compressed bytes)
pub fn adler32_and_deflate(
  bytes : Bytes,
  start : Int,
  len : Int,
  level : DeflateLevel?,
) -> Result[(UInt32, Bytes), String] {
  let adler = bytes_adler32(bytes, start, len)
  match deflate(bytes, start, len, level) {
    Ok(compressed) => Ok((adler, compressed))
    Err(msg) => Err(msg)
  }
}
