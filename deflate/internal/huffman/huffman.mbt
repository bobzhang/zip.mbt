///|
/// Huffman coding for DEFLATE compression (RFC 1951)
/// 
/// Provides encoder and decoder structures for Huffman codes used in
/// DEFLATE compression. Supports both fixed and dynamic Huffman codes.

///|
/// Constants for DEFLATE Huffman coding
let litlen_sym_max : Int = 285 // Maximum literal/length symbol

///|
let litlen_sym_fixed_max : Int = 287 // Max for fixed Huffman

///|
let dist_sym_max : Int = 29 // Maximum distance symbol

///|
/// Huffman decoder for inflate (decompression)
struct HuffmanDecoder {
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
/// Initialize a Huffman decoder from code lengths
pub fn HuffmanDecoder::init_from_lengths(
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
/// Get the max_sym field (maximum symbol seen)
pub fn HuffmanDecoder::max_sym(self : HuffmanDecoder) -> Int {
  self.max_sym
}

///|
/// Get count for a specific code length
pub fn HuffmanDecoder::count(self : HuffmanDecoder, len : Int) -> Int {
  self.counts[len]
}

///|
/// Get symbol at a specific index
pub fn HuffmanDecoder::symbol(self : HuffmanDecoder, index : Int) -> Int {
  self.symbols[index]
}

///|
/// Get the length of counts array
pub fn HuffmanDecoder::counts_length(self : HuffmanDecoder) -> Int {
  self.counts.length()
}

///|
/// Get the length of symbols array
pub fn HuffmanDecoder::symbols_length(self : HuffmanDecoder) -> Int {
  self.symbols.length()
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
/// Symbol info packs code and code length into a single Int
/// Bits layout: code (upper bits) | code_length (lower 5 bits)
/// This allows efficient storage and access
pub struct SymInfo(Int)

///|
/// Create symbol info from code and code length
pub fn sym_info_make(code : Int, code_length : Int) -> SymInfo {
  SymInfo((code << 5) | code_length)
}

///|
/// Extract code from symbol info
pub fn sym_info_code(info : SymInfo) -> Int {
  info.0 >> 5
}

///|
/// Extract code length from symbol info
pub fn sym_info_code_length(info : SymInfo) -> Int {
  info.0 & 0x1F
}

///|
/// Huffman encoder for deflate compression
/// Stores symbol-to-code mappings
struct HuffmanEncoder {
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
/// Get the max_sym field (maximum symbol that has a code)
pub fn HuffmanEncoder::max_sym(self : HuffmanEncoder) -> Int {
  self.max_sym
}

///|
/// Get the length of codes array
pub fn HuffmanEncoder::codes_length(self : HuffmanEncoder) -> Int {
  self.codes.length()
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
pub fn reverse_bits(value : Int, length : Int) -> Int {
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
