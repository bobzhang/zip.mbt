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
/// CRC-32 checksum implementation
// CRC-32 checksum using the polynomial 0xedb88320 (ZIP standard)

pub struct Crc32 {
  value : UInt32
} derive(Eq, Show)

///|
let crc32_poly : UInt32 = 0xedb88320L

// CRC-32 lookup table (256 entries)

///|
let crc32_table : Array[UInt32] = {
  let table = Array::make(256, 0L)
  for i = 0; i < 256; i = i + 1 {
    let mut c = i.to_int64()
    for k = 0; k < 8; k = k + 1 {
      c = if (c & 1L) != 0L { crc32_poly ^ (c >> 1) } else { c >> 1 }
    }
    table[i] = c
  }
  table
}

///|
/// Crc32 operations
pub fn Crc32::init() -> Crc32 {
  { value: 0xFFFFFFFFL }
}

///|
pub fn Crc32::finish(self : Crc32) -> UInt32 {
  self.value ^ 0xFFFFFFFFL
}

///|
pub fn Crc32::update_byte(self : Crc32, byte : Int) -> Crc32 {
  let index = self.value.lxor(byte.to_int64()).land(0xFFL).to_int()
  let new_value = crc32_table[index] ^ (self.value >> 8)
  { value: new_value }
}

///|
pub fn Crc32::update_bytes(
  self : Crc32,
  bytes : Bytes,
  start : Int,
  len : Int,
) -> Crc32 {
  let mut crc = self
  for i = start; i < start + len; i = i + 1 {
    crc = crc.update_byte(bytes[i].to_int())
  }
  crc
}

///|
pub fn bytes_crc32(bytes : Bytes, start : Int, len : Int) -> UInt32 {
  Crc32::init().update_bytes(bytes, start, len).finish()
}

///|
pub fn check_crc32(expect : UInt32, found : UInt32) -> Result[Unit, String] {
  if expect == found {
    Ok(())
  } else {
    let msg = "CRC-32 mismatch: expected \{expect.to_hex_string()}, found \{found.to_hex_string()}"
    Err(msg)
  }
}

///|
/// Adler-32 checksum implementation
pub struct Adler32 {
  value : UInt32
} derive(Eq, Show)

///|
let adler32_base : UInt32 = 65521L

///|
pub fn Adler32::init() -> Adler32 {
  { value: 1L }
}

///|
pub fn Adler32::finish(self : Adler32) -> UInt32 {
  self.value
}

///|
pub fn Adler32::update_bytes(
  self : Adler32,
  bytes : Bytes,
  start : Int,
  len : Int,
) -> Adler32 {
  let mut s1 = self.value & 0xFFFFL
  let mut s2 = self.value >> 16
  let mut pos = start
  let max = start + len
  while pos < max {
    // Process in blocks to avoid overflow
    let block_len = if len - (pos - start) < 5552 {
      len - (pos - start)
    } else {
      5552
    }
    let block_max = pos + block_len

    // Process block
    while pos < block_max {
      s1 = s1 + bytes[pos].to_int().to_int64()
      s2 = s2 + s1
      pos = pos + 1
    }
    s1 = s1 % adler32_base
    s2 = s2 % adler32_base
  }
  { value: (s2 << 16) | s1 }
}

///|
pub fn bytes_adler32(bytes : Bytes, start : Int, len : Int) -> UInt32 {
  Adler32::init().update_bytes(bytes, start, len).finish()
}

///|
pub fn check_adler32(expect : UInt32, found : UInt32) -> Result[Unit, String] {
  if expect == found {
    Ok(())
  } else {
    let msg = "Adler-32 mismatch: expected \{expect.to_hex_string()}, found \{found.to_hex_string()}"
    Err(msg)
  }
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
/// Extensible byte buffer for decompression output
/// Similar to OCaml's Buffer but with self-blit support for LZ77 back-references
struct ByteBuf {
  mut buffer : Array[Byte]
  mut length : Int
  fixed : Bool // If true, buffer cannot grow (size is known)
}

///|
/// Create a new byte buffer
pub fn ByteBuf::new(size : Int, fixed : Bool) -> ByteBuf {
  let actual_size = if size == 0 && not(fixed) { 1024 } else { size }
  { buffer: Array::make(actual_size, b'\x00'), length: 0, fixed }
}

///|
/// Get current length of data in buffer
pub fn ByteBuf::length(self : ByteBuf) -> Int {
  self.length
}

///|
/// Get contents as Bytes
pub fn ByteBuf::contents(self : ByteBuf) -> Bytes {
  // Convert Array to Bytes using literal syntax
  Bytes::from_fixedarray(
    FixedArray::from_iter(self.buffer[0:self.length].iter()),
  )
}

///|
/// Grow the buffer to ensure it can hold at least 'ensure' bytes
fn ByteBuf::grow(self : ByteBuf, ensure : Int) -> Unit {
  if self.fixed {
    abort("Expected decompression size exceeded")
  }
  let mut new_len = self.buffer.length()
  while new_len < ensure {
    new_len = new_len * 2
  }
  let new_buffer = Array::make(new_len, b'\x00')
  for i = 0; i < self.length; i = i + 1 {
    new_buffer[i] = self.buffer[i]
  }
  self.buffer = new_buffer
}

///|
/// Add a single byte to the buffer
pub fn ByteBuf::add_byte(self : ByteBuf, byte : Int) -> Unit {
  let new_len = self.length + 1
  if new_len > self.buffer.length() {
    self.grow(new_len)
  }
  self.buffer[self.length] = byte.to_byte()
  self.length = new_len
}

///|
/// Add bytes from a Bytes object
pub fn ByteBuf::add_bytes(
  self : ByteBuf,
  src : Bytes,
  start : Int,
  len : Int,
) -> Unit {
  let new_len = self.length + len
  if new_len > self.buffer.length() {
    self.grow(new_len)
  }
  for i = 0; i < len; i = i + 1 {
    self.buffer[self.length + i] = src[start + i]
  }
  self.length = new_len
}

///|
/// Copy bytes from earlier in the buffer (for LZ77 back-references)
/// This handles overlapping copies correctly (needed for RLE patterns)
pub fn ByteBuf::recopy(self : ByteBuf, start : Int, len : Int) -> Unit {
  let new_len = self.length + len
  if new_len > self.buffer.length() {
    self.grow(new_len)
  }
  // Always copy byte-by-byte to handle overlapping correctly
  let dst_start = self.length
  for i = 0; i < len; i = i + 1 {
    self.buffer[dst_start + i] = self.buffer[start + i]
  }
  self.length = new_len
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
/// Convert backslashes to forward slashes (for Windows paths)
pub fn fpath_ensure_unix(path : Fpath) -> Fpath {
  let mut result = ""
  for i = 0; i < path.length(); i = i + 1 {
    let c = path[i]
    if c == '\\' {
      result = result + "/"
    } else {
      result = result + c.to_string()
    }
  }
  result
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
  let mut current = ""
  for i = 0; i < path.length(); i = i + 1 {
    let c = path[i]
    if c == '/' || c == '\\' {
      if keep_segment(current) {
        segments.push(current)
      }
      current = ""
    } else {
      current = current + c.to_string()
    }
  }

  // Don't forget the last segment
  if keep_segment(current) {
    segments.push(current)
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
/// POSIX time utilities for ZIP archives

///|
/// POSIX time (seconds since Unix epoch: 1970-01-01 00:00:00 UTC)
pub typealias Int as Ptime

///|
/// DOS epoch: 1980-01-01 00:00:00 UTC (in POSIX time)
/// This is the earliest representable time in ZIP archives
pub let dos_epoch : Ptime = 315532800

///|
let jd_posix_epoch : Int = 2440588 // Julian day of POSIX epoch

///|
/// Convert POSIX time to ((year, month, day), (hour, minute, second))
pub fn ptime_to_date_time(
  ptime_s : Ptime,
) -> ((Int, Int, Int), (Int, Int, Int)) {
  // Calculate Julian day
  let jd = ptime_s / 86400 + jd_posix_epoch
  let jd_rem = ptime_s % 86400

  // Time components
  let hh = jd_rem / 3600
  let hh_rem = jd_rem % 3600
  let mm = hh_rem / 60
  let ss = hh_rem % 60

  // Date from Julian day (algorithm from ptime library)
  let a = jd + 32044
  let b = (4 * a + 3) / 146097
  let c = a - 146097 * b / 4
  let d = (4 * c + 3) / 1461
  let e = c - 1461 * d / 4
  let m = (5 * e + 2) / 153
  let day = e - (153 * m + 2) / 5 + 1
  let month = m + 3 - 12 * (m / 10)
  let year = 100 * b + d - 4800 + m / 10
  ((year, month, day), (hh, mm, ss))
}

///|
/// Convert MS-DOS date/time to POSIX time
pub fn ptime_of_dos_date_time(dos_date : Int, dos_time : Int) -> Ptime {
  if dos_date < 0x21 {
    // Before 1980-01-01
    dos_epoch
  } else {
    // Extract time components
    let hh = dos_time >> 11
    let mm = (dos_time >> 5) & 0x3F
    let ss = (dos_time & 0x1F) * 2

    // Extract date components and compute Julian day
    let year = ((dos_date >> 9) & 0x7F) + 1980
    let month = (dos_date >> 5) & 0xF
    let day = dos_date & 0x1F

    // Julian day calculation
    let a = (14 - month) / 12
    let y = year + 4800 - a
    let m = month + 12 * a - 3
    let jd = day +
      (153 * m + 2) / 5 +
      365 * y +
      y / 4 -
      y / 100 +
      y / 400 -
      32045
    let d = jd - jd_posix_epoch
    d * 86400 + hh * 3600 + mm * 60 + ss
  }
}

///|
/// Convert POSIX time to MS-DOS date/time format
pub fn ptime_to_dos_date_time(ptime_s : Ptime) -> (Int, Int) {
  let date_time = ptime_to_date_time(ptime_s)
  let ((y, _, _), _) = date_time
  let ((year, month, day), (hh, mm, ss)) = if y < 1980 {
    ((1980, 1, 1), (0, 0, 0))
  } else if y > 2107 {
    ((2107, 12, 31), (23, 59, 59))
  } else {
    date_time
  }
  let dos_date = day | (month << 5) | ((year - 1980) << 9)
  let dos_time = (ss / 2) | (mm << 5) | (hh << 11)
  (dos_date, dos_time)
}

///|
/// Format POSIX time as RFC 3339 (without T separator)
pub fn ptime_format(ptime : Ptime) -> String {
  let ((year, month, day), (hh, mm, ss)) = ptime_to_date_time(ptime)
  // Format: YYYY-MM-DD HH:MM:SSZ
  fn pad2(n : Int) -> String {
    if n < 10 {
      "0" + n.to_string()
    } else {
      n.to_string()
    }
  }

  fn pad4(n : Int) -> String {
    if n < 10 {
      "000" + n.to_string()
    } else if n < 100 {
      "00" + n.to_string()
    } else if n < 1000 {
      "0" + n.to_string()
    } else {
      n.to_string()
    }
  }

  pad4(year) +
  "-" +
  pad2(month) +
  "-" +
  pad2(day) +
  " " +
  pad2(hh) +
  ":" +
  pad2(mm) +
  ":" +
  pad2(ss) +
  "Z"
}

///|
/// Compression formats supported in ZIP archives
pub(all) enum Compression {
  Stored // No compression
  Deflate // Deflate compression (RFC 1951)
  Bzip2 // Bzip2 (not supported)
  Lzma // LZMA (not supported)
  Xz // XZ (not supported)
  Zstd // Zstandard (not supported)
  Other(Int) // Unknown compression method
} derive(Eq, Show)

///|
/// Convert compression format to ZIP method number
pub fn Compression::to_int(self : Compression) -> Int {
  match self {
    Stored => 0
    Deflate => 8
    Bzip2 => 12
    Lzma => 14
    Zstd => 93
    Xz => 95
    Other(n) => n
  }
}

///|
/// Convert ZIP method number to compression format
pub fn Compression::from_int(compression_method : Int) -> Compression {
  match compression_method {
    0 => Stored
    8 => Deflate
    12 => Bzip2
    14 => Lzma
    93 => Zstd
    95 => Xz
    n => Other(n)
  }
}

///|
/// Convert compression format to human-readable string
pub fn Compression::to_string(self : Compression) -> String {
  match self {
    Stored => "stored"
    Deflate => "deflate"
    Bzip2 => "bzip2"
    Lzma => "lzma"
    Zstd => "zstd"
    Xz => "xz"
    Other(n) => "other(\{n})"
  }
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
/// Note: Only None is currently implemented; others are reserved for future use
pub enum DeflateLevel {
  None // No compression, use stored blocks only
  Fast // Fast compression (TODO)
  Default // Default compression (TODO)
  Best // Best compression (TODO)
} derive(Eq)

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
/// Bit-level output writer for deflate compression
/// Accumulates bits and writes complete bytes to the output buffer
pub(all) struct BitWriter {
  dst : ByteBuf // Output buffer
  mut bits : Int // Accumulated bits (up to 31 bits)
  mut bits_len : Int // Number of valid bits in 'bits'
}

///|
/// Create a new BitWriter
pub fn BitWriter::new(dst : ByteBuf) -> BitWriter {
  { dst, bits: 0, bits_len: 0 }
}

///|
/// Write N bits to the output stream (N <= 16)
/// Bits are written LSB first (as required by deflate format)
pub fn BitWriter::write_bits(self : BitWriter, value : Int, count : Int) -> Unit {
  self.bits = self.bits | (value << self.bits_len)
  self.bits_len = self.bits_len + count
  // Flush complete bytes
  while self.bits_len >= 8 {
    self.dst.add_byte(self.bits & 0xFF)
    self.bits = self.bits >> 8
    self.bits_len = self.bits_len - 8
  }
}

///|
/// Flush any remaining bits to output (pad with zeros)
pub fn BitWriter::flush(self : BitWriter) -> Unit {
  if self.bits_len > 0 {
    self.dst.add_byte(self.bits & 0xFF)
    self.bits = 0
    self.bits_len = 0
  }
}

///|
/// Align to byte boundary (flush and discard partial bits)
pub fn BitWriter::align_to_byte(self : BitWriter) -> Unit {
  if self.bits_len > 0 {
    self.bits = 0
    self.bits_len = 0
  }
}

///|
/// Write a byte directly to output (should be byte-aligned)
pub fn BitWriter::write_byte(self : BitWriter, byte : Int) -> Unit {
  if self.bits_len != 0 {
    abort("BitWriter::write_byte called when not byte-aligned")
  }
  self.dst.add_byte(byte)
}

///|
/// Write a 16-bit little-endian value directly (should be byte-aligned)
pub fn BitWriter::write_uint16_le(self : BitWriter, value : Int) -> Unit {
  if self.bits_len != 0 {
    abort("BitWriter::write_uint16_le called when not byte-aligned")
  }
  self.dst.add_byte(value & 0xFF)
  self.dst.add_byte((value >> 8) & 0xFF)
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
/// Create deflate-compressed file data from bytes
/// Note: Currently uses uncompressed deflate blocks (stored format)
/// Full LZ77+Huffman deflate compression is TODO
pub fn File::deflate_of_bytes(
  bytes : Bytes,
  start : Int,
  len : Int,
  _level : DeflateLevel?,
) -> Result[File, String] {
  // For now, ignore level and always use stored blocks
  let compressed = deflate_stored(bytes, start, len)
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
  let path = filename_bytes.to_string()

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
    let path_bytes = m.path().to_bytes()
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
    let path_bytes = m.path().to_bytes()
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
