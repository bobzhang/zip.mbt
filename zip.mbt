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
let litlen_sym_fixed_max : Int = 287

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
/// Huffman decoder for inflate
pub struct HuffmanDecoder {
  counts : Array[Int] // counts[i] = number of codes of length i
  symbols : Array[Int] // symbols sorted by code
  mut max_sym : Int // maximum symbol seen
}

///|
/// Create a new Huffman decoder
pub fn HuffmanDecoder::new() -> HuffmanDecoder {
  let max_code_bit_length = 15
  let max_symbol_count = litlen_sym_fixed_max + 1
  {
    counts: Array::make(max_code_bit_length + 1, 0),
    symbols: Array::make(max_symbol_count, 0),
    max_sym: 0,
  }
}

///|
/// Fixed Huffman decoder for literal/length symbols (RFC 1951 3.2.6)
pub let fixed_litlen_decoder : HuffmanDecoder = {
  let decoder = HuffmanDecoder::new()
  // Fixed code lengths from RFC 1951:
  // - symbols 0-143: 8 bits
  // - symbols 144-255: 9 bits
  // - symbols 256-279: 7 bits
  // - symbols 280-287: 8 bits
  decoder.counts[7] = 24 // 256-279
  decoder.counts[8] = 152 // 0-143 + 280-287 = 144 + 8
  decoder.counts[9] = 112 // 144-255
  // Symbols sorted by code length then by value
  for i = 0; i < 24; i = i + 1 {
    decoder.symbols[i] = 256 + i // 256-279 (7 bits)
  }
  for i = 0; i < 144; i = i + 1 {
    decoder.symbols[24 + i] = i // 0-143 (8 bits)
  }
  for i = 0; i < 8; i = i + 1 {
    decoder.symbols[168 + i] = 280 + i // 280-287 (8 bits)
  }
  for i = 0; i < 112; i = i + 1 {
    decoder.symbols[176 + i] = 144 + i // 144-255 (9 bits)
  }
  decoder.max_sym = litlen_sym_max
  decoder
}

///|
/// Fixed Huffman decoder for distance symbols (RFC 1951 3.2.6)
pub let fixed_dist_decoder : HuffmanDecoder = {
  let decoder = HuffmanDecoder::new()
  // All 32 distance symbols use 5 bits
  decoder.counts[5] = 32
  for i = 0; i < 32; i = i + 1 {
    decoder.symbols[i] = i
  }
  decoder.max_sym = dist_sym_max
  decoder
}

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
/// Initialize a Huffman decoder from code lengths
fn HuffmanDecoder::init_from_lengths(
  self : HuffmanDecoder,
  lengths : Array[Int],
  start : Int,
  lengths_len : Int,
) -> Unit {
  // Clear counts
  for i = 0; i < self.counts.length(); i = i + 1 {
    self.counts[i] = 0
  }
  self.max_sym = -1

  // Count number of codes for each non-zero length
  for i = 0; i < lengths_len; i = i + 1 {
    let len = lengths[start + i]
    if len != 0 {
      self.max_sym = i
      self.counts[len] = self.counts[len] + 1
    }
  }

  // Compute offset table for distribution sort
  let offs = Array::make(16, 0)
  let mut available = 1
  let mut num_codes = 0
  for i = 0; i < 16; i = i + 1 {
    let used = self.counts[i]
    if used > available {
      abort("Corrupted deflate stream: invalid Huffman code")
    }
    available = 2 * (available - used)
    offs[i] = num_codes
    num_codes = num_codes + used
  }

  // Check all codes are used or if only one that its length is one
  if (num_codes > 1 && available > 0) || (num_codes == 1 && self.counts[1] != 1) {
    abort("Corrupted deflate stream: invalid Huffman code")
  }

  // Fill in symbols sorted by code
  for i = 0; i < lengths_len; i = i + 1 {
    let leni = lengths[start + i]
    if leni != 0 {
      let off = offs[leni]
      self.symbols[off] = i
      offs[leni] = off + 1
    }
  }

  // For only one code (which would be 0) add a code 1 which results in a symbol
  // that is too large
  if num_codes == 1 {
    self.counts[1] = 2
    self.symbols[1] = self.max_sym + 1
  }
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
/// File path type (just a String in MoonBit)
pub typealias String as Fpath

///|
/// Unix file mode (permission bits)
pub typealias Int as FileMode

///|
/// Convert string to UTF-8 bytes for ZIP encoding
fn string_to_utf8_bytes(s : String) -> Bytes {
  @encoding/utf8.encode(s)
}

///|
/// Convert backslashes to forward slashes (for Windows paths)
pub fn fpath_ensure_unix(path : Fpath) -> Fpath {
  let chars : Array[Char] = []
  for i = 0; i < path.length(); i = i + 1 {
    let code = path[i]
    let c = code.unsafe_to_char()
    if c == '\\' {
      let _ = chars.push('/')
    } else {
      let _ = chars.push(c)
    }
  }
  String::from_array(chars)
}

///|
/// Ensure path ends with '/' (for directories)
pub fn fpath_ensure_directoryness(path : Fpath) -> Fpath {
  if path == "" {
    "./"
  } else if path[path.length() - 1] == '/' {
    path
  } else {
    path + "/"
  }
}

///|
/// Sanitize a file path by removing dangerous segments
/// Removes: empty segments, ".", "..", and absolute path markers
pub fn fpath_sanitize(path : Fpath) -> Fpath {
  fn keep_segment(seg : String) -> Bool {
    seg != "" && seg != "." && seg != ".."
  }

  // Split on both / and \
  let segments : Array[String] = []
  let current_chars : Array[Char] = []
  for i = 0; i < path.length(); i = i + 1 {
    let code = path[i]
    let c = code.unsafe_to_char()
    if c == '/' || c == '\\' {
      if current_chars.length() > 0 {
        let current = String::from_array(current_chars)
        if keep_segment(current) {
          let _ = segments.push(current)
        }
        current_chars.clear()
      }
    } else {
      let _ = current_chars.push(c)
    }
  }

  // Don't forget the last segment
  if current_chars.length() > 0 {
    let current = String::from_array(current_chars)
    if keep_segment(current) {
      let _ = segments.push(current)
    }
  }

  // Join with /
  if segments.is_empty() {
    ""
  } else {
    let mut result = segments[0]
    for i = 1; i < segments.length(); i = i + 1 {
      result = result + "/" + segments[i]
    }
    result
  }
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

///|
/// Create uncompressed deflate blocks (RFC 1951)
/// This creates valid deflate format using only stored (uncompressed) blocks
fn deflate_stored(bytes : Bytes, start : Int, len : Int) -> Bytes {
  // Deflate format with stored blocks:
  // Each block: 1 byte header + 4 bytes length info + data
  // We'll use a single block for simplicity
  let max_block_size = 65535 // Maximum size for a stored block
  if len <= max_block_size {
    // Single block
    let result_size = 1 + 4 + len // header + len info + data
    let result = Array::make(result_size, b'\x00')

    // Block header: BFINAL=1 (last block), BTYPE=00 (no compression)
    result[0] = (0b00000001).to_byte()

    // Length (little-endian)
    result[1] = (len & 0xFF).to_byte()
    result[2] = ((len >> 8) & 0xFF).to_byte()

    // One's complement of length
    let nlen = len ^ 0xFFFF
    result[3] = (nlen & 0xFF).to_byte()
    result[4] = ((nlen >> 8) & 0xFF).to_byte()

    // Copy data
    for i = 0; i < len; i = i + 1 {
      result[5 + i] = bytes[start + i]
    }
    Bytes::from_fixedarray(FixedArray::from_iter(result[0:].iter()))
  } else {
    // Multiple blocks needed (not yet implemented)
    abort("Deflate compression for data > 65535 bytes not yet implemented")
  }
}

///|
/// Huffman Encoder for deflate compression
/// Stores symbol-to-code mappings (code and code length)

///|
/// Symbol info packs code and code length into a single Int
/// Bits layout: code (upper bits) | code_length (lower 5 bits)
/// This allows efficient storage and access
pub typealias Int as SymInfo

///|
pub fn sym_info_make(code : Int, code_length : Int) -> SymInfo {
  (code << 5) | code_length
}

///|
pub fn sym_info_code(info : SymInfo) -> Int {
  info >> 5
}

///|
pub fn sym_info_code_length(info : SymInfo) -> Int {
  info & 0x1F
}

///|
/// Huffman encoder - array of symbol info indexed by symbol
pub struct HuffmanEncoder {
  codes : Array[SymInfo] // codes[symbol] = sym_info for that symbol
  mut max_sym : Int // Maximum symbol that has a code
}

///|
/// Create a new Huffman encoder
pub fn HuffmanEncoder::new() -> HuffmanEncoder {
  // Need room for all possible symbols including fixed codes (0-287)
  { codes: Array::make(litlen_sym_fixed_max + 1, 0), max_sym: 0 }
}

///|
/// Get symbol info for a given symbol
pub fn HuffmanEncoder::get(self : HuffmanEncoder, symbol : Int) -> SymInfo {
  self.codes[symbol]
}

///|
/// Set symbol info for a given symbol
pub fn HuffmanEncoder::set(
  self : HuffmanEncoder,
  symbol : Int,
  info : SymInfo,
) -> Unit {
  self.codes[symbol] = info
  if sym_info_code_length(info) > 0 && symbol > self.max_sym {
    self.max_sym = symbol
  }
}

///|
/// Helper function to reverse bits (for Huffman codes)
fn reverse_bits(value : Int, length : Int) -> Int {
  let mut result = 0
  let mut v = value
  for _i = 0; _i < length; _i = _i + 1 {
    result = (result << 1) | (v & 1)
    v = v >> 1
  }
  result
}

///|
/// Fixed Huffman encoder for literal/length symbols (RFC 1951 3.2.6)
/// Precomputed codes for fast compression
pub let fixed_litlen_encoder : HuffmanEncoder = {
  let encoder = HuffmanEncoder::new()
  // RFC 1951 3.2.6: Fixed Huffman codes
  // Symbols   0-143: 8 bits, codes 00110000-10111111  (0x30-0xBF)
  // Symbols 144-255: 9 bits, codes 110010000-111111111 (0x190-0x1FF)
  // Symbols 256-279: 7 bits, codes 0000000-0010111    (0x00-0x17)
  // Symbols 280-287: 8 bits, codes 11000000-11000111  (0xC0-0xC7)
  
  // Symbols 256-279: 7 bits (0000000-0010111)
  for i = 256; i <= 279; i = i + 1 {
    let code = reverse_bits(i - 256, 7)
    encoder.set(i, sym_info_make(code, 7))
  }
  
  // Symbols 0-143: 8 bits (00110000-10111111)
  for i = 0; i <= 143; i = i + 1 {
    let code = reverse_bits(0x30 + i, 8)
    encoder.set(i, sym_info_make(code, 8))
  }
  
  // Symbols 280-287: 8 bits (11000000-11000111)
  for i = 280; i <= 287; i = i + 1 {
    let code = reverse_bits(0xC0 + (i - 280), 8)
    encoder.set(i, sym_info_make(code, 8))
  }
  
  // Symbols 144-255: 9 bits (110010000-111111111)
  for i = 144; i <= 255; i = i + 1 {
    let code = reverse_bits(0x190 + (i - 144), 9)
    encoder.set(i, sym_info_make(code, 9))
  }
  
  encoder.max_sym = litlen_sym_max
  encoder
}

///|
/// Fixed Huffman encoder for distance symbols (RFC 1951 3.2.6)
/// All 32 distance symbols use 5 bits
pub let fixed_dist_encoder : HuffmanEncoder = {
  let encoder = HuffmanEncoder::new()
  
  // All 32 symbols (0-31) use 5 bits
  for i = 0; i < 32; i = i + 1 {
    let code = reverse_bits(i, 5)
    encoder.set(i, sym_info_make(code, 5))
  }
  
  encoder.max_sym = dist_sym_max
  encoder
}

///|
/// Build optimal Huffman code lengths from frequency counts
/// Uses proper Huffman tree algorithm with Package-Merge length limiting
/// Returns array of code lengths (0 = unused symbol)
fn build_optimal_code_lengths(
  freqs : Array[Int],
  max_sym : Int,
  max_code_len : Int
) -> Array[Int] {
  let lengths = Array::make(max_sym + 1, 0)
  
  // Count non-zero frequencies
  let mut count = 0
  for i = 0; i <= max_sym; i = i + 1 {
    if freqs[i] > 0 {
      count = count + 1
    }
  }
  
  // Trivial cases
  if count == 0 {
    return lengths // All zeros
  }
  if count == 1 {
    // Single symbol gets length 1
    for i = 0; i <= max_sym; i = i + 1 {
      if freqs[i] > 0 {
        lengths[i] = 1
        break
      }
    }
    return lengths
  }
  if count == 2 {
    // Two symbols get length 1 each
    let mut found = 0
    for i = 0; i <= max_sym && found < 2; i = i + 1 {
      if freqs[i] > 0 {
        lengths[i] = 1
        found = found + 1
      }
    }
    return lengths
  }
  
  // Build standard Huffman tree
  // Nodes: (freq, id) where id < max_sym means leaf, id >= max_sym means internal
  let heap = Array::make(count * 2, (0, 0))
  let mut heap_size = 0
  
  // Add leaves
  for i = 0; i <= max_sym; i = i + 1 {
    if freqs[i] > 0 {
      heap[heap_size] = (freqs[i], i)
      heap_size = heap_size + 1
    }
  }
  
  // Parent table: parent[node_id] = (parent_id, is_left_child)
  // -1 means no parent (root)
  let parent = Array::make((max_sym + 1) + count, -1)
  let mut next_internal_id = max_sym + 1
  
  // Build tree
  while heap_size > 1 {
    // Extract two minimums
    let mut min1_idx = 0
    for i = 1; i < heap_size; i = i + 1 {
      if heap[i].0 < heap[min1_idx].0 {
        min1_idx = i
      }
    }
    let node1 = heap[min1_idx]
    heap[min1_idx] = heap[heap_size - 1]
    heap_size = heap_size - 1
    
    let mut min2_idx = 0
    for i = 1; i < heap_size; i = i + 1 {
      if heap[i].0 < heap[min2_idx].0 {
        min2_idx = i
      }
    }
    let node2 = heap[min2_idx]
    
    // Create parent
    parent[node1.1] = next_internal_id
    parent[node2.1] = next_internal_id
    
    heap[min2_idx] = (node1.0 + node2.0, next_internal_id)
    next_internal_id = next_internal_id + 1
  }
  
  // Compute depths
  for i = 0; i <= max_sym; i = i + 1 {
    if freqs[i] > 0 {
      let mut depth = 0
      let mut node_id = i
      while parent[node_id] != -1 {
        depth = depth + 1
        node_id = parent[node_id]
      }
      lengths[i] = if depth > max_code_len { max_code_len } else { depth }
    }
  }
  
  lengths
}

///|
/// Build canonical Huffman codes from code lengths
/// Returns a HuffmanEncoder with proper codes assigned
fn build_canonical_huffman(
  lengths : Array[Int],
  max_sym : Int
) -> HuffmanEncoder {
  let encoder = HuffmanEncoder::new()
  
  // Count codes of each length
  let count = Array::make(16, 0)
  for i = 0; i <= max_sym; i = i + 1 {
    let len = lengths[i]
    if len > 0 {
      count[len] = count[len] + 1
    }
  }
  
  // Compute first code for each length (canonical Huffman)
  count[0] = 0
  let next_code = Array::make(16, 0)
  let mut code = 0
  for len = 1; len <= 15; len = len + 1 {
    code = (code + count[len - 1]) << 1
    next_code[len] = code
  }
  
  // Assign codes to symbols
  for sym = 0; sym <= max_sym; sym = sym + 1 {
    let len = lengths[sym]
    if len > 0 {
      let c = next_code[len]
      let bits = reverse_bits(c, len)
      encoder.set(sym, sym_info_make(bits, len))
      next_code[len] = c + 1
    }
  }
  
  encoder
}

///|
/// Code length order for dynamic Huffman (RFC 1951 3.2.7)
let codelen_order : Array[Int] = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

///|
/// Encode code lengths with run-length compression
/// Returns (encoded_symbols, frequencies, symbol_count)
/// Symbols 0-15: literal code length
/// Symbol 16: repeat previous 3-6 times (2 extra bits)
/// Symbol 17: repeat zero 3-10 times (3 extra bits)
/// Symbol 18: repeat zero 11-138 times (7 extra bits)
fn encode_code_lengths(
  litlen_lengths : Array[Int],
  dist_lengths : Array[Int],
  hlit : Int,
  hdist : Int
) -> (Array[Int], Array[Int], Int) {
  // Concatenate litlen and dist lengths
  let litlen_count = hlit + 257
  let dist_count = hdist + 1
  let total = litlen_count + dist_count
  
  let all_lengths = Array::make(total, 0)
  for i = 0; i < litlen_count; i = i + 1 {
    all_lengths[i] = litlen_lengths[i]
  }
  for i = 0; i < dist_count; i = i + 1 {
    all_lengths[litlen_count + i] = dist_lengths[i]
  }
  
  // Run-length encode
  // Store symbol in lower 8 bits, extra bits in upper bits
  let codelen_syms = Array::make(total + 100, 0) // Extra space for RLE overhead
  let codelen_freqs = Array::make(19, 0) // 19 codelen symbols
  let mut sym_count = 0
  
  let mut i = 0
  while i < total {
    let len = all_lengths[i]
    
    if len == 0 {
      // Count consecutive zeros
      let mut zero_count = 1
      while i + zero_count < total && all_lengths[i + zero_count] == 0 && zero_count < 138 {
        zero_count = zero_count + 1
      }
      
      if zero_count < 3 {
        // Output as literal
        codelen_syms[sym_count] = 0
        codelen_freqs[0] = codelen_freqs[0] + 1
        sym_count = sym_count + 1
        i = i + 1
      } else if zero_count <= 10 {
        // Use symbol 17 (repeat zero 3-10 times)
        let extra = zero_count - 3
        codelen_syms[sym_count] = 17 | (extra << 8)
        codelen_freqs[17] = codelen_freqs[17] + 1
        sym_count = sym_count + 1
        i = i + zero_count
      } else {
        // Use symbol 18 (repeat zero 11-138 times)
        let extra = zero_count - 11
        codelen_syms[sym_count] = 18 | (extra << 8)
        codelen_freqs[18] = codelen_freqs[18] + 1
        sym_count = sym_count + 1
        i = i + zero_count
      }
    } else {
      // Non-zero length - output as literal first
      codelen_syms[sym_count] = len
      codelen_freqs[len] = codelen_freqs[len] + 1
      sym_count = sym_count + 1
      i = i + 1
      
      // Check for repeats of the same non-zero length (up to max 6)
      let mut repeat_count = 0
      let max_look = (i + 5).min(total) // Look ahead up to 6 total
      while i + repeat_count < max_look && all_lengths[i + repeat_count] == len {
        repeat_count = repeat_count + 1
      }
      
      if repeat_count >= 3 {
        // Use symbol 16 (repeat previous 3-6 times)
        // Already output the first one, so repeat_count is how many MORE to repeat
        let extra = repeat_count - 3
        codelen_syms[sym_count] = 16 | (extra << 8)
        codelen_freqs[16] = codelen_freqs[16] + 1
        sym_count = sym_count + 1
        i = i + repeat_count
      }
      // If repeat_count < 3, just continue - they'll be output as literals in next iterations
    }
  }
  
  (codelen_syms, codelen_freqs, sym_count)
}

///|
/// Write dynamic Huffman block header
fn write_dynamic_header(
  writer : BitWriter,
  litlen_encoder : HuffmanEncoder,
  dist_encoder : HuffmanEncoder,
  codelen_encoder : HuffmanEncoder,
  codelen_syms : Array[Int],
  sym_count : Int,
  hlit : Int,
  hdist : Int
) -> Unit {
  // Find last non-zero codelen code length (in the special order)
  let mut hclen_idx = 18
  while hclen_idx > 0 {
    let sym = codelen_order[hclen_idx]
    if sym_info_code_length(codelen_encoder.get(sym)) > 0 {
      break
    }
    hclen_idx = hclen_idx - 1
  }
  
  // Ensure we have at least 4 codes (HCLEN can't be negative)
  if hclen_idx < 3 {
    hclen_idx = 3
  }
  
  // HCLEN is the number of code length codes minus 4
  // hclen_idx + 1 is the count of codes to write
  let hclen = hclen_idx + 1 - 4
  
  // Write HLIT (5 bits) - number of litlen codes minus 257
  writer.write_bits(hlit, 5)
  
  // Write HDIST (5 bits) - number of dist codes minus 1
  writer.write_bits(hdist, 5)
  
  // Write HCLEN (4 bits) - number of codelen codes minus 4
  writer.write_bits(hclen, 4)
  
  // Write codelen code lengths (3 bits each, in special order)
  for i = 0; i <= hclen_idx; i = i + 1 {
    let sym = codelen_order[i]
    let len = sym_info_code_length(codelen_encoder.get(sym))
    writer.write_bits(len, 3)
  }
  
  // Write encoded litlen and dist code lengths
  for i = 0; i < sym_count; i = i + 1 {
    let sym_with_extra = codelen_syms[i]
    let sym = sym_with_extra & 0xFF
    let extra_bits = sym_with_extra >> 8
    
    let info = codelen_encoder.get(sym)
    let code = sym_info_code(info)
    let code_len = sym_info_code_length(info)
    
    writer.write_bits(code, code_len)
    
    // Write extra bits for symbols 16, 17, 18
    if sym == 16 {
      writer.write_bits(extra_bits, 2)
    } else if sym == 17 {
      writer.write_bits(extra_bits, 3)
    } else if sym == 18 {
      writer.write_bits(extra_bits, 7)
    }
  }
}

///|
/// Convert a match length (3-258) to the corresponding literal/length symbol (257-285)
pub fn length_to_symbol(length : Int) -> Int {
  // Binary search would be more efficient but this is simple
  // Length range: 3-258 -> Symbols: 257-285
  if length <= 10 {
    // Symbols 257-264: lengths 3-10
    257 + (length - 3)
  } else if length <= 18 {
    // Symbols 265-268: 11,13,15,17 (base + 0 or 1)
    265 + ((length - 11) / 2)
  } else if length <= 34 {
    // Symbols 269-272: 19,23,27,31 (base + 0-3)
    269 + ((length - 19) / 4)
  } else if length <= 66 {
    // Symbols 273-276: 35,43,51,59 (base + 0-7)
    273 + ((length - 35) / 8)
  } else if length <= 130 {
    // Symbols 277-280: 67,83,99,115 (base + 0-15)
    277 + ((length - 67) / 16)
  } else if length <= 257 {
    // Symbols 281-284: 131,163,195,227 (base + 0-31)
    281 + ((length - 131) / 32)
  } else {
    // Symbol 285: length 258
    285
  }
}

///|
/// Convert a distance (1-32768) to the corresponding distance symbol (0-29)
pub fn distance_to_symbol(dist : Int) -> Int {
  // Distance table is more regular: each pair of symbols doubles the range
  if dist <= 4 {
    dist - 1 // Symbols 0-3: distances 1-4
  } else if dist <= 8 {
    4 + ((dist - 5) >> 1) // Symbols 4-5
  } else if dist <= 16 {
    6 + ((dist - 9) >> 2) // Symbols 6-7
  } else if dist <= 32 {
    8 + ((dist - 17) >> 3) // Symbols 8-9
  } else if dist <= 64 {
    10 + ((dist - 33) >> 4) // Symbols 10-11
  } else if dist <= 128 {
    12 + ((dist - 65) >> 5) // Symbols 12-13
  } else if dist <= 256 {
    14 + ((dist - 129) >> 6) // Symbols 14-15
  } else if dist <= 512 {
    16 + ((dist - 257) >> 7) // Symbols 16-17
  } else if dist <= 1024 {
    18 + ((dist - 513) >> 8) // Symbols 18-19
  } else if dist <= 2048 {
    20 + ((dist - 1025) >> 9) // Symbols 20-21
  } else if dist <= 4096 {
    22 + ((dist - 2049) >> 10) // Symbols 22-23
  } else if dist <= 8192 {
    24 + ((dist - 4097) >> 11) // Symbols 24-25
  } else if dist <= 16384 {
    26 + ((dist - 8193) >> 12) // Symbols 26-27
  } else {
    28 + ((dist - 16385) >> 13) // Symbols 28-29
  }
}

///|
/// Write a literal or end-of-block symbol using fixed Huffman
pub fn write_literal_symbol(
  writer : BitWriter,
  encoder : HuffmanEncoder,
  symbol : Int,
) -> Unit {
  let info = encoder.get(symbol)
  let code = sym_info_code(info)
  let len = sym_info_code_length(info)
  writer.write_bits(code, len)
}

///|
/// Write a length/distance pair using fixed Huffman
pub fn write_length_distance(
  writer : BitWriter,
  litlen_encoder : HuffmanEncoder,
  dist_encoder : HuffmanEncoder,
  length : Int,
  distance : Int,
) -> Unit {
  // Write length symbol
  let len_sym = length_to_symbol(length)
  let len_info = litlen_encoder.get(len_sym)
  let len_code = sym_info_code(len_info)
  let len_code_len = sym_info_code_length(len_info)
  writer.write_bits(len_code, len_code_len)
  
  // Write extra bits for length
  let len_value = length_value_of_length_sym(len_sym)
  let len_base = length_value_base(len_value)
  let len_extra_bits = length_value_extra_bits(len_value)
  if len_extra_bits > 0 {
    let extra = length - len_base
    writer.write_bits(extra, len_extra_bits)
  }
  
  // Write distance symbol
  let dist_sym = distance_to_symbol(distance)
  let dist_info = dist_encoder.get(dist_sym)
  let dist_code = sym_info_code(dist_info)
  let dist_code_len = sym_info_code_length(dist_info)
  writer.write_bits(dist_code, dist_code_len)
  
  // Write extra bits for distance
  let dist_value = dist_value_of_sym[dist_sym]
  let dist_base = dist_value_base(dist_value)
  let dist_extra_bits = dist_value_extra_bits(dist_value)
  if dist_extra_bits > 0 {
    let extra = distance - dist_base
    writer.write_bits(extra, dist_extra_bits)
  }
}

///|
/// Frequency counter for dynamic Huffman code construction
/// Tracks symbol frequencies during LZ77 compression
struct FrequencyCounter {
  litlen_freqs : Array[Int] // 286 symbols (0-285)
  dist_freqs : Array[Int] // 30 symbols (0-29)
}

///|
/// Create a new frequency counter
fn FrequencyCounter::new() -> FrequencyCounter {
  { litlen_freqs: Array::make(286, 0), dist_freqs: Array::make(30, 0) }
}

///|
/// Record a literal symbol
fn FrequencyCounter::add_literal(self : FrequencyCounter, lit : Int) -> Unit {
  self.litlen_freqs[lit] = self.litlen_freqs[lit] + 1
}

///|
/// Record a length symbol
fn FrequencyCounter::add_length(self : FrequencyCounter, length : Int) -> Unit {
  let sym = length_to_symbol(length)
  self.litlen_freqs[sym] = self.litlen_freqs[sym] + 1
}

///|
/// Record a distance symbol
fn FrequencyCounter::add_distance(self : FrequencyCounter, dist : Int) -> Unit {
  let sym = distance_to_symbol(dist)
  self.dist_freqs[sym] = self.dist_freqs[sym] + 1
}

///|
/// Record end-of-block symbol (always exactly one per block)
fn FrequencyCounter::add_end_of_block(self : FrequencyCounter) -> Unit {
  self.litlen_freqs[256] = 1
}

///|
/// Deflate Level None: Write uncompressed data as fixed Huffman literals
/// This is valid compression but produces larger output than LZ77+Huffman
/// Used as a stepping stone before implementing full LZ77
pub fn deflate_fixed_literals_only(
  bytes : Bytes,
  start : Int,
  len : Int,
  is_final : Bool,
) -> Bytes {
  let output = ByteBuf::new(len * 2, false) // Estimate 2x size for safety
  let writer = BitWriter::new(output)
  
  // Write block header: BFINAL (1 bit) + BTYPE (2 bits) = 01 for fixed Huffman
  let header = if is_final { 0b011 } else { 0b010 } // BFINAL=1/0, BTYPE=01
  writer.write_bits(header, 3)
  
  // Write all bytes as literals using fixed Huffman codes
  for i = 0; i < len; i = i + 1 {
    let byte = bytes[start + i].to_int()
    write_literal_symbol(writer, fixed_litlen_encoder, byte)
  }
  
  // Write end-of-block symbol (256)
  write_literal_symbol(writer, fixed_litlen_encoder, litlen_end_of_block_sym)
  
  writer.flush()
  output.contents()
}

// ============================================================================
// LZ77 String Matching (for deflate compression)
// ============================================================================

// LZ77 constants
let lz77_min_match_len : Int = 3 // Minimum match length
let lz77_max_match_len : Int = 258 // Maximum match length (same as length_max)
let lz77_max_match_dist : Int = 32768 // Maximum back-reference distance
let lz77_window_size : Int = 32768 // Sliding window size
let lz77_hash_bit_size : Int = 15 // Hash table size = 2^15 = 32768
let lz77_hash_size : Int = 32768 // 1 << lz77_hash_bit_size
let lz77_no_pos : Int = -1 // Marker for no position

///|
/// Compute rolling hash of 4 bytes starting at position i
/// Uses Fibonacci hashing: multiply by golden ratio and take upper bits
pub fn hash4(bytes : Bytes, i : Int) -> Int {
  // Read 4 bytes as little-endian Int32
  let b0 = bytes[i].to_int()
  let b1 = bytes[i + 1].to_int()
  let b2 = bytes[i + 2].to_int()
  let b3 = bytes[i + 3].to_int()
  let v = b0.lor(b1 << 8).lor(b2 << 16).lor(b3 << 24)
  
  // Fibonacci hash: multiply by golden ratio approximation
  let hmul = 0x9E3779B1 // 2^32 / phi, where phi = golden ratio
  let product = v * hmul
  
  // Take upper bits (shift right to get most significant bits)
  (product >> (32 - lz77_hash_bit_size)).land(0x7FFF) // Keep 15 bits
}

///|
/// Insert position into hash chain
pub fn insert_hash(hash_head : Array[Int], hash_prev : Array[Int], hash : Int, pos : Int) -> Unit {
  hash_prev[pos.mod(lz77_window_size)] = hash_head[hash]
  hash_head[hash] = pos
}

///|
/// Match bytes backward from positions i and j for len bytes
/// Returns -1 if all match, or the count of remaining unmatched bytes
fn match_bwd(bytes : Bytes, i : Int, j : Int, len : Int) -> Int {
  if len < 0 {
    return len
  }
  if bytes[i].to_int() == bytes[j].to_int() {
    match_bwd(bytes, i - 1, j - 1, len - 1)
  } else {
    len
  }
}

///|
/// Match bytes forward from positions i and j, up to max_match_len
/// Returns the length of the match
pub fn match_fwd(bytes : Bytes, i : Int, j : Int, len : Int, max_match_len : Int) -> Int {
  if len >= max_match_len {
    return len
  }
  if i >= bytes.length() || j >= bytes.length() {
    return len
  }
  if bytes[i].to_int() == bytes[j].to_int() {
    match_fwd(bytes, i + 1, j + 1, len + 1, max_match_len)
  } else {
    len
  }
}

///|
/// Find match length between positions i and j
/// Only returns a length if it's strictly longer than prev_match_len
/// Uses bidirectional matching: check backward first, then forward
pub fn find_match_length(
  bytes : Bytes,
  i : Int,
  j : Int,
  prev_match_len : Int,
  max_match_len : Int
) -> Int {
  let newi = i + prev_match_len
  let newj = j + prev_match_len
  
  if newi >= bytes.length() || newj >= bytes.length() {
    return 0
  }
  
  // Check backward from prev_match_len position
  if match_bwd(bytes, newi, newj, prev_match_len) < 0 {
    // Backward match succeeded, try forward
    match_fwd(bytes, newi + 1, newj + 1, prev_match_len + 1, max_match_len)
  } else {
    0 // Backward match failed
  }
}

///|
/// Back-reference: represents a (distance, length) pair for LZ77
/// Packed into a single Int: (distance << 16) | length
/// If distance == 0, it's a literal (length is the byte value)
pub fn make_backref(dist : Int, len : Int) -> Int {
  (dist << 16).lor(len)
}

pub fn backref_dist(bref : Int) -> Int {
  // Extract upper 16 bits, handling the bit pattern correctly
  let bits = bref.land(-65536) // Mask to keep only upper 16 bits
  if bits < 0 {
    // Negative means bit 31 was set, need to handle as unsigned
    (bits >> 16).land(0xFFFF)
  } else {
    bits >> 16
  }
}

pub fn backref_len(bref : Int) -> Int {
  bref.land(0xFFFF)
}

///|
/// Find the best back-reference match starting at position pos
/// Returns a backref (0 if no good match found)
/// Uses hash chain to search previous positions with same hash
/// Parameters:
/// - good_match: If match >= this length, reduce search effort (quality vs speed)
/// - max_chain_len: Maximum number of hash chain entries to check
pub fn find_backref(
  bytes : Bytes,
  hash_head : Array[Int],
  hash_prev : Array[Int],
  pos : Int,
  hash : Int,
  prev_match_len : Int,
  max_match_len : Int,
  good_match : Int,
  max_chain_len : Int
) -> Int {
  // Adjust prev_match_len: we want at least lz77_min_match_len
  let prev_len = if prev_match_len == 0 {
    lz77_min_match_len - 1
  } else {
    prev_match_len
  }
  
  // Early exit if already at max
  if prev_len >= max_match_len {
    return 0
  }
  
  // Adjust chain length based on match quality
  let chain_steps = if prev_len >= good_match {
    max_chain_len / 4 // Reduce effort if we already have a good match
  } else {
    max_chain_len
  }
  
  // Search the hash chain for best match
  fn search_chain(chain_left : Int, i : Int, match_pos : Int, best_len : Int) -> Int {
    if i == lz77_no_pos || chain_left == 0 || pos - i > lz77_max_match_dist {
      // End of chain or out of range
      if match_pos == lz77_no_pos {
        0 // No match found
      } else {
        make_backref(pos - match_pos, best_len)
      }
    } else {
      // Try to find match at position i
      let len = find_match_length(bytes, i, pos, best_len, max_match_len)
      
      if len == max_match_len {
        // Found maximum possible match, stop searching
        make_backref(pos - i, len)
      } else if len > 0 {
        // Found a better match, continue searching
        let next_i = hash_prev[i.mod(lz77_window_size)]
        search_chain(chain_left - 1, next_i, i, len)
      } else {
        // No better match, continue searching
        let next_i = hash_prev[i.mod(lz77_window_size)]
        search_chain(chain_left - 1, next_i, match_pos, best_len)
      }
    }
  }
  
  let start_i = hash_head[hash]
  search_chain(chain_steps, start_i, lz77_no_pos, prev_len)
}

///|
/// Deflate compression with LZ77 + Fixed Huffman
/// This is the main compression function that implements:
/// - LZ77 string matching with hash chains
/// - Lazy matching for better compression
/// - Fixed Huffman encoding
pub fn deflate_fixed(
  bytes : Bytes,
  start : Int,
  len : Int,
  is_final : Bool,
  good_match : Int,
  max_chain : Int
) -> Bytes {
  if len == 0 {
    // Empty input, just write end-of-block
    let output = ByteBuf::new(10, false)
    let writer = BitWriter::new(output)
    let header = if is_final { 0b011 } else { 0b010 }
    writer.write_bits(header, 3)
    write_literal_symbol(writer, fixed_litlen_encoder, litlen_end_of_block_sym)
    writer.flush()
    return output.contents()
  }
  
  // Initialize hash tables
  let hash_head = Array::make(lz77_hash_size, lz77_no_pos)
  let hash_prev = Array::make(lz77_window_size, 0)
  
  // Output buffer
  let output = ByteBuf::new(len * 2, false)
  let writer = BitWriter::new(output)
  
  // Write block header
  let header = if is_final { 0b011 } else { 0b010 }
  writer.write_bits(header, 3)
  
  // Compression loop with lazy matching
  let max_pos = start + len - lz77_min_match_len
  
  fn compress_loop(pos : Int, prev_bref : Int) -> Unit {
    if pos > max_pos {
      // Handle end of input
      let prev_len = backref_len(prev_bref)
      let final_pos = if prev_len == 0 {
        pos
      } else {
        // Write pending match
        let dist = backref_dist(prev_bref)
        write_length_distance(writer, fixed_litlen_encoder, fixed_dist_encoder, prev_len, dist)
        pos - 1 + prev_len
      }
      
      // Write remaining literals
      let end = start + len
      for i = final_pos; i < end; i = i + 1 {
        let byte = bytes[i].to_int()
        write_literal_symbol(writer, fixed_litlen_encoder, byte)
      }
      
      // Write end-of-block
      write_literal_symbol(writer, fixed_litlen_encoder, litlen_end_of_block_sym)
    } else {
      // Check if we have enough bytes to compute hash
      if pos + 4 > start + len {
        // Not enough bytes for hash, just output as literal
        if prev_bref > 0 {
          let prev_len = backref_len(prev_bref)
          let dist = backref_dist(prev_bref)
          write_length_distance(writer, fixed_litlen_encoder, fixed_dist_encoder, prev_len, dist)
          compress_loop(pos - 1 + prev_len, 0)
        } else {
          let byte = bytes[pos].to_int()
          write_literal_symbol(writer, fixed_litlen_encoder, byte)
          compress_loop(pos + 1, 0)
        }
        return
      }
      
      // Search for match at current position
      let hash = hash4(bytes, pos)
      let max_match = (start + len - pos).min(lz77_max_match_len)
      let prev_len = backref_len(prev_bref)
      
      let cur_bref = find_backref(
        bytes,
        hash_head,
        hash_prev,
        pos,
        hash,
        prev_len,
        max_match,
        good_match,
        max_chain
      )
      let cur_len = backref_len(cur_bref)
      
      // Insert current position into hash
      insert_hash(hash_head, hash_prev, hash, pos)
      
      // Lazy matching: decide whether to use previous or current match
      if prev_len > 0 && prev_len >= cur_len {
        // Previous match is better, use it
        let dist = backref_dist(prev_bref)
        write_length_distance(writer, fixed_litlen_encoder, fixed_dist_encoder, prev_len, dist)
        
        // Insert skipped positions into hash
        let next = pos - 1 + prev_len
        let last = (next - 1).min(max_pos)
        for j = pos + 1; j <= last; j = j + 1 {
          if j + 3 < start + len {
            let h = hash4(bytes, j)
            insert_hash(hash_head, hash_prev, h, j)
          }
        }
        
        compress_loop(next, 0)
      } else if cur_len == 0 {
        // No match found
        if prev_len > 0 {
          // Output previous position as literal (rejected lazy match)
          let byte = bytes[pos - 1].to_int()
          write_literal_symbol(writer, fixed_litlen_encoder, byte)
        } else {
          // No previous match either, output current as literal
          let byte = bytes[pos].to_int()
          write_literal_symbol(writer, fixed_litlen_encoder, byte)
        }
        compress_loop(pos + 1, 0)
      } else {
        // Found a match, defer decision to next iteration (lazy matching)
        if prev_len > 0 {
          // Reject previous match, output as literal
          let byte = bytes[pos - 1].to_int()
          write_literal_symbol(writer, fixed_litlen_encoder, byte)
        }
        compress_loop(pos + 1, cur_bref)
      }
    }
  }
  
  compress_loop(start, 0)
  writer.flush()
  output.contents()
}

///|
/// Deflate compression with LZ77 + Dynamic Huffman
/// This provides better compression than fixed Huffman by building
/// optimal Huffman trees for each block based on symbol frequencies
pub fn deflate_dynamic(
  bytes : Bytes,
  start : Int,
  len : Int,
  is_final : Bool,
  good_match : Int,
  max_chain : Int
) -> Bytes {
  if len == 0 {
    // Empty input, just write end-of-block with fixed Huffman
    let output = ByteBuf::new(10, false)
    let writer = BitWriter::new(output)
    let header = if is_final { 0b011 } else { 0b010 }
    writer.write_bits(header, 3)
    write_literal_symbol(writer, fixed_litlen_encoder, litlen_end_of_block_sym)
    writer.flush()
    return output.contents()
  }
  
  // Step 1: Run LZ77 compression and collect symbol frequencies
  let hash_head = Array::make(lz77_hash_size, lz77_no_pos)
  let hash_prev = Array::make(lz77_window_size, 0)
  let freqs = FrequencyCounter::new()
  
  // Store symbols for later output
  let max_symbols = len + 1000 // Extra space for LZ77 symbols
  let symbols = Array::make(max_symbols, 0)
  let mut sym_idx = 0
  
  let max_pos = start + len - lz77_min_match_len
  
  fn compress_and_count(pos : Int, prev_bref : Int) -> Unit {
    if pos > max_pos {
      // Handle end of input
      let prev_len = backref_len(prev_bref)
      let final_pos = if prev_len == 0 {
        pos
      } else {
        // Record pending match
        let dist = backref_dist(prev_bref)
        freqs.add_length(prev_len)
        freqs.add_distance(dist)
        symbols[sym_idx] = prev_bref
        sym_idx = sym_idx + 1
        pos - 1 + prev_len
      }
      
      // Record remaining literals
      let end = start + len
      for i = final_pos; i < end; i = i + 1 {
        let byte = bytes[i].to_int()
        freqs.add_literal(byte)
        symbols[sym_idx] = byte // Literal has dist=0
        sym_idx = sym_idx + 1
      }
      
      // Add end-of-block
      freqs.add_end_of_block()
    } else {
      if pos + 4 > start + len {
        // Not enough bytes for hash
        if prev_bref > 0 {
          let prev_len = backref_len(prev_bref)
          let dist = backref_dist(prev_bref)
          freqs.add_length(prev_len)
          freqs.add_distance(dist)
          symbols[sym_idx] = prev_bref
          sym_idx = sym_idx + 1
          compress_and_count(pos - 1 + prev_len, 0)
        } else {
          let byte = bytes[pos].to_int()
          freqs.add_literal(byte)
          symbols[sym_idx] = byte
          sym_idx = sym_idx + 1
          compress_and_count(pos + 1, 0)
        }
        return
      }
      
      let hash = hash4(bytes, pos)
      let max_match = (start + len - pos).min(lz77_max_match_len)
      let prev_len = backref_len(prev_bref)
      
      let cur_bref = find_backref(
        bytes,
        hash_head,
        hash_prev,
        pos,
        hash,
        prev_len,
        max_match,
        good_match,
        max_chain
      )
      let cur_len = backref_len(cur_bref)
      
      insert_hash(hash_head, hash_prev, hash, pos)
      
      if prev_len > 0 && prev_len >= cur_len {
        // Use previous match
        let dist = backref_dist(prev_bref)
        freqs.add_length(prev_len)
        freqs.add_distance(dist)
        symbols[sym_idx] = prev_bref
        sym_idx = sym_idx + 1
        
        let next = pos - 1 + prev_len
        let last = (next - 1).min(max_pos)
        for j = pos + 1; j <= last; j = j + 1 {
          if j + 3 < start + len {
            let h = hash4(bytes, j)
            insert_hash(hash_head, hash_prev, h, j)
          }
        }
        
        compress_and_count(next, 0)
      } else if cur_len == 0 {
        // No match
        if prev_len > 0 {
          let byte = bytes[pos - 1].to_int()
          freqs.add_literal(byte)
          symbols[sym_idx] = byte
          sym_idx = sym_idx + 1
        } else {
          let byte = bytes[pos].to_int()
          freqs.add_literal(byte)
          symbols[sym_idx] = byte
          sym_idx = sym_idx + 1
        }
        compress_and_count(pos + 1, 0)
      } else {
        // Lazy matching
        if prev_len > 0 {
          let byte = bytes[pos - 1].to_int()
          freqs.add_literal(byte)
          symbols[sym_idx] = byte
          sym_idx = sym_idx + 1
        }
        compress_and_count(pos + 1, cur_bref)
      }
    }
  }
  
  compress_and_count(start, 0)
  
  // Step 2: Build optimal Huffman trees from frequencies
  let litlen_lengths = build_optimal_code_lengths(freqs.litlen_freqs, 285, 15)
  let litlen_encoder = build_canonical_huffman(litlen_lengths, 285)
  
  // Find max non-zero litlen symbol (index)
  // Must include at least 0-256 (literals + end-of-block)
  let mut litlen_max = 285
  while litlen_max > 256 && litlen_lengths[litlen_max] == 0 {
    litlen_max = litlen_max - 1
  }
  // litlen_max is now at least 256 (for end-of-block symbol)
  // HLIT = (number of codes) - 257
  // Number of codes = max_index + 1
  let hlit = (litlen_max + 1) - 257
  
  // Build distance tree
  let dist_lengths = build_optimal_code_lengths(freqs.dist_freqs, 29, 15)
  let mut dist_encoder = build_canonical_huffman(dist_lengths, 29)
  
  // Find max non-zero dist symbol (index)
  let mut dist_max = 29
  while dist_max > 0 && dist_lengths[dist_max] == 0 {
    dist_max = dist_max - 1
  }
  
  // Handle empty distance tree (no matches, only literals)
  let hdist = if dist_max == 0 && dist_lengths[0] == 0 {
    // Patch with a single code of length 1 for symbol 0
    dist_lengths[0] = 1  // Update the lengths array
    dist_encoder = HuffmanEncoder::new()
    dist_encoder.set(0, sym_info_make(0, 1))
    0 // HDIST = 0 means 1 code (dist_count = 1)
  } else {
    // HDIST = (number of codes) - 1
    // Number of codes = max_index + 1
    (dist_max + 1) - 1  // = dist_max
  }
  
  // Step 3: Encode code lengths
  let (codelen_syms, codelen_freqs, codelen_count) = encode_code_lengths(
    litlen_lengths,
    dist_lengths,
    hlit,
    hdist
  )
  
  // Step 4: Build codelen Huffman tree
  let codelen_lengths = build_optimal_code_lengths(codelen_freqs, 18, 7)
  let codelen_encoder = build_canonical_huffman(codelen_lengths, 18)
  
  // Step 5: Write dynamic block
  let output = ByteBuf::new(len * 2, false)
  let writer = BitWriter::new(output)
  
  // Write block header (BFINAL + BTYPE=10 for dynamic Huffman)
  let header = if is_final { 0b101 } else { 0b100 }
  writer.write_bits(header, 3)
  
  // Write dynamic header
  write_dynamic_header(
    writer,
    litlen_encoder,
    dist_encoder,
    codelen_encoder,
    codelen_syms,
    codelen_count,
    hlit,
    hdist
  )
  
  // Step 6: Write block symbols using dynamic Huffman codes
  for i = 0; i < sym_idx; i = i + 1 {
    let sym = symbols[i]
    let dist = backref_dist(sym)
    
    if dist == 0 {
      // Literal
      let lit = backref_len(sym)
      write_literal_symbol(writer, litlen_encoder, lit)
    } else {
      // Match (length + distance)
      let length = backref_len(sym)
      write_length_distance(writer, litlen_encoder, dist_encoder, length, dist)
    }
  }
  
  // Write end-of-block
  write_literal_symbol(writer, litlen_encoder, litlen_end_of_block_sym)
  
  writer.flush()
  output.contents()
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
  let fcheck = flg.land(0x1F)
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
