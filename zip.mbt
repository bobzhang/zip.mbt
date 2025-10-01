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
let length_value_max : Int = 258

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
let dist_sym_fixed_max : Int = 31

///|
let dist_value_max : Int = 32768

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
let codelen_sym_max : Int = 18

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
struct InflateDecoder {
  src : Bytes // Source compressed data
  src_max : Int // Maximum valid index in src
  mut src_pos : Int // Current read position
  mut src_bits : Int // Buffered bits (up to 31 bits)
  mut src_bits_len : Int // Number of valid bits in src_bits
  dst : ByteBuf // Output buffer
  dyn_litlen : HuffmanDecoder // Dynamic literal/length decoder
  dyn_dist : HuffmanDecoder // Dynamic distance decoder
  crc_state : Crc32 // For CRC-32 computation
  mut crc_next : Int // Position in dst for next CRC update
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
    crc_state: Crc32::init(),
    crc_next: 0,
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
