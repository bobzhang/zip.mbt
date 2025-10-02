// Deflate compression and decompression (RFC 1951)
// Implements both the inflate decoder and deflate encoder

// Re-export dependencies
typealias @buffer.ByteBuf as ByteBuf
typealias @bitstream.BitWriter as BitWriter
typealias @huffman.HuffmanDecoder as HuffmanDecoder
typealias @huffman.HuffmanEncoder as HuffmanEncoder
typealias @huffman.SymInfo as SymInfo

// Type aliases for checksums
typealias Int64 as UInt32

// Constants from RFC 1951
pub let litlen_sym_max : Int = 285
pub let litlen_end_of_block_sym : Int = 256
pub let litlen_first_len_sym : Int = 257

pub let dist_sym_max : Int = 29
pub let max_dist_sym_count : Int = 30

pub let max_codelen_sym_count : Int = 19

// Code length order for dynamic Huffman (RFC 1951 3.2.7)
pub let codelen_order : Array[Int] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
]

// Length value functions
fn length_value_base(v : Int) -> Int {
  v >> 4
}

fn length_value_extra_bits(v : Int) -> Int {
  v & 0xF
}

// Distance value functions
fn dist_value_base(v : Int) -> Int {
  v >> 4
}

fn dist_value_extra_bits(v : Int) -> Int {
  v & 0xF
}

// Length and distance value tables
pub fn length_value_of_length_sym(sym : Int) -> Int {
  // Symbol must be 257-285
  let length_value_table : Array[Int] = [
    3 << 4, 4 << 4, 5 << 4, 6 << 4, 7 << 4, 8 << 4, 9 << 4, 10 << 4,
    (11 << 4) | 1, (13 << 4) | 1, (15 << 4) | 1, (17 << 4) | 1,
    (19 << 4) | 2, (23 << 4) | 2, (27 << 4) | 2, (31 << 4) | 2,
    (35 << 4) | 3, (43 << 4) | 3, (51 << 4) | 3, (59 << 4) | 3,
    (67 << 4) | 4, (83 << 4) | 4, (99 << 4) | 4, (115 << 4) | 4,
    (131 << 4) | 5, (163 << 4) | 5, (195 << 4) | 5, (227 << 4) | 5,
    258 << 4,
  ]
  length_value_table[sym - 257]
}

pub let dist_value_of_sym : Array[Int] = [
  1 << 4, 2 << 4, 3 << 4, 4 << 4,
  (5 << 4) | 1, (7 << 4) | 1,
  (9 << 4) | 2, (13 << 4) | 2,
  (17 << 4) | 3, (25 << 4) | 3,
  (33 << 4) | 4, (49 << 4) | 4,
  (65 << 4) | 5, (97 << 4) | 5,
  (129 << 4) | 6, (193 << 4) | 6,
  (257 << 4) | 7, (385 << 4) | 7,
  (513 << 4) | 8, (769 << 4) | 8,
  (1025 << 4) | 9, (1537 << 4) | 9,
  (2049 << 4) | 10, (3073 << 4) | 10,
  (4097 << 4) | 11, (6145 << 4) | 11,
  (8193 << 4) | 12, (12289 << 4) | 12,
  (16385 << 4) | 13, (24577 << 4) | 13,
]

// ============================================================================
// Inflate Decoder (Decompression)
// ============================================================================

/// Inflate decoder state
pub struct InflateDecoder {
  src : Bytes // Source compressed data
  src_max : Int // Maximum valid index in src
  mut src_pos : Int // Current read position
  mut src_bits : Int // Buffered bits (up to 31 bits)
  mut src_bits_len : Int // Number of valid bits in src_bits
  dst : ByteBuf // Output buffer
  dyn_litlen : HuffmanDecoder // Dynamic literal/length decoder
  dyn_dist : HuffmanDecoder // Dynamic distance decoder
}

/// Create a new inflate decoder
pub fn InflateDecoder::new(
  src : Bytes,
  start : Int,
  len : Int,
  decompressed_size : Int?,
) -> InflateDecoder {
  let src_max = start + len - 1
  let dst = match decompressed_size {
    Some(size) => @buffer.ByteBuf::new(size, true)
    None => @buffer.ByteBuf::new(len * 3, false)
  }
  {
    src,
    src_max,
    src_pos: start,
    src_bits: 0,
    src_bits_len: 0,
    dst,
    dyn_litlen: @huffman.HuffmanDecoder::new(),
    dyn_dist: @huffman.HuffmanDecoder::new(),
  }
}

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

/// Read a symbol using a Huffman decoder
fn InflateDecoder::read_symbol(
  self : InflateDecoder,
  decoder : HuffmanDecoder,
) -> Int {
  read_symbol_loop(self, decoder, 1, 0, 0)
}

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

/// Read a block compressed with fixed Huffman codes
fn read_fixed_block(decoder : InflateDecoder) -> Unit {
  read_block_symbols(decoder, @huffman.fixed_litlen_decoder, @huffman.fixed_dist_decoder)
}

/// Read a block compressed with dynamic Huffman codes
fn read_dynamic_block(decoder : InflateDecoder) -> Unit {
  // Read number of literal/length codes (257-286)
  let hlit = decoder.read_int(257, 5)
  // Read number of distance codes (1-32)
  let hdist = decoder.read_int(1, 5)
  if hlit > 286 || hdist > max_dist_sym_count {
    abort("Corrupted deflate stream: invalid dynamic block header")
  }

  // Read number of code length codes (4-19)
  let hclen = decoder.read_int(4, 4)

  // Read code length code lengths
  let codelen_lengths = Array::make(max_codelen_sym_count, 0)
  for i = 0; i < hclen; i = i + 1 {
    codelen_lengths[codelen_order[i]] = decoder.read_bits(3)
  }

  // Build Huffman decoder for code lengths (temporarily use dyn_litlen)
  decoder.dyn_litlen.init_from_lengths(
    codelen_lengths, 0, max_codelen_sym_count,
  )
  if decoder.dyn_litlen.max_sym == -1 {
    abort("Corrupted deflate stream: empty code length code")
  }

  // Decode the literal/length and distance code lengths
  let lengths = Array::make(286 + max_dist_sym_count, 0)
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

/// Decompress deflate format data (RFC 1951)
pub fn inflate(
  src : Bytes,
  start : Int,
  len : Int,
  decompressed_size : Int?,
) -> Bytes {
  let decoder = InflateDecoder::new(src, start, len, decompressed_size)
  inflate_loop(decoder)
}

/// Decompress deflate data and compute CRC-32
pub fn inflate_and_crc32(
  src : Bytes,
  start : Int,
  len : Int,
  decompressed_size : Int?,
) -> (Bytes, UInt32) {
  let decoder = InflateDecoder::new(src, start, len, decompressed_size)
  let result = inflate_loop(decoder)
  // Compute CRC-32 of the decompressed data
  let crc = @crc32.bytes_crc32(result, 0, result.length())
  (result, crc)
}

/// Decompress deflate data and compute Adler-32
pub fn inflate_and_adler32(
  src : Bytes,
  start : Int,
  len : Int,
  decompressed_size : Int?,
) -> (Bytes, UInt32) {
  let decoder = InflateDecoder::new(src, start, len, decompressed_size)
  let result = inflate_loop(decoder)
  // Compute Adler-32 of the decompressed data
  let adler = @adler32.bytes_adler32(result, 0, result.length())
  (result, adler)
}

// ============================================================================
// Deflate Encoder (Compression)
// ============================================================================

/// Create stored (uncompressed) deflate blocks (RFC 1951)
pub fn deflate_stored(bytes : Bytes, start : Int, len : Int) -> Bytes {
  let max_block_size = 65535
  if len <= max_block_size {
    // Single block
    let result_size = 1 + 4 + len
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
    abort("Deflate compression for data > 65535 bytes not yet implemented")
  }
}

/// Build optimal Huffman code lengths from frequency counts
pub fn build_optimal_code_lengths(
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
    return lengths
  }
  if count == 1 {
    for i = 0; i <= max_sym; i = i + 1 {
      if freqs[i] > 0 {
        lengths[i] = 1
        break
      }
    }
    return lengths
  }
  if count == 2 {
    let mut found = 0
    for i = 0; i <= max_sym && found < 2; i = i + 1 {
      if freqs[i] > 0 {
        lengths[i] = 1
        found = found + 1
      }
    }
    return lengths
  }
  
  // Build Huffman tree
  let heap = Array::make(count * 2, (0, 0))
  let mut heap_size = 0
  
  for i = 0; i <= max_sym; i = i + 1 {
    if freqs[i] > 0 {
      heap[heap_size] = (freqs[i], i)
      heap_size = heap_size + 1
    }
  }
  
  let parent = Array::make((max_sym + 1) + count, -1)
  let mut next_internal_id = max_sym + 1
  
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

/// Build canonical Huffman codes from code lengths
pub fn build_canonical_huffman(
  lengths : Array[Int],
  max_sym : Int
) -> HuffmanEncoder {
  let encoder = @huffman.HuffmanEncoder::new()
  
  let count = Array::make(16, 0)
  for i = 0; i <= max_sym; i = i + 1 {
    let len = lengths[i]
    if len > 0 {
      count[len] = count[len] + 1
    }
  }
  
  count[0] = 0
  let next_code = Array::make(16, 0)
  let mut code = 0
  for len = 1; len <= 15; len = len + 1 {
    code = (code + count[len - 1]) << 1
    next_code[len] = code
  }
  
  for sym = 0; sym <= max_sym; sym = sym + 1 {
    let len = lengths[sym]
    if len > 0 {
      let c = next_code[len]
      let bits = @huffman.reverse_bits(c, len)
      encoder.set(sym, @huffman.sym_info_make(bits, len))
      next_code[len] = c + 1
    }
  }
  
  encoder
}

/// Encode code lengths with run-length compression
pub fn encode_code_lengths(
  litlen_lengths : Array[Int],
  dist_lengths : Array[Int],
  hlit : Int,
  hdist : Int
) -> (Array[Int], Array[Int], Int) {
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
  
  let codelen_syms = Array::make(total + 100, 0)
  let codelen_freqs = Array::make(19, 0)
  let mut sym_count = 0
  
  let mut i = 0
  while i < total {
    let len = all_lengths[i]
    
    if len == 0 {
      let mut zero_count = 1
      while i + zero_count < total && all_lengths[i + zero_count] == 0 && zero_count < 138 {
        zero_count = zero_count + 1
      }
      
      if zero_count < 3 {
        codelen_syms[sym_count] = 0
        codelen_freqs[0] = codelen_freqs[0] + 1
        sym_count = sym_count + 1
        i = i + 1
      } else if zero_count <= 10 {
        let extra = zero_count - 3
        codelen_syms[sym_count] = 17 | (extra << 8)
        codelen_freqs[17] = codelen_freqs[17] + 1
        sym_count = sym_count + 1
        i = i + zero_count
      } else {
        let extra = zero_count - 11
        codelen_syms[sym_count] = 18 | (extra << 8)
        codelen_freqs[18] = codelen_freqs[18] + 1
        sym_count = sym_count + 1
        i = i + zero_count
      }
    } else {
      codelen_syms[sym_count] = len
      codelen_freqs[len] = codelen_freqs[len] + 1
      sym_count = sym_count + 1
      i = i + 1
      
      let mut repeat_count = 0
      let max_look = (i + 5).min(total)
      while i + repeat_count < max_look && all_lengths[i + repeat_count] == len {
        repeat_count = repeat_count + 1
      }
      
      if repeat_count >= 3 {
        let extra = repeat_count - 3
        codelen_syms[sym_count] = 16 | (extra << 8)
        codelen_freqs[16] = codelen_freqs[16] + 1
        sym_count = sym_count + 1
        i = i + repeat_count
      }
    }
  }
  
  (codelen_syms, codelen_freqs, sym_count)
}

/// Write dynamic Huffman block header
pub fn write_dynamic_header(
  writer : BitWriter,
  litlen_encoder : HuffmanEncoder,
  dist_encoder : HuffmanEncoder,
  codelen_encoder : HuffmanEncoder,
  codelen_syms : Array[Int],
  sym_count : Int,
  hlit : Int,
  hdist : Int
) -> Unit {
  let mut hclen_idx = 18
  while hclen_idx > 0 {
    let sym = codelen_order[hclen_idx]
    if @huffman.sym_info_code_length(codelen_encoder.get(sym)) > 0 {
      break
    }
    hclen_idx = hclen_idx - 1
  }
  
  if hclen_idx < 3 {
    hclen_idx = 3
  }
  
  let hclen = hclen_idx + 1 - 4
  
  writer.write_bits(hlit, 5)
  writer.write_bits(hdist, 5)
  writer.write_bits(hclen, 4)
  
  for i = 0; i <= hclen_idx; i = i + 1 {
    let sym = codelen_order[i]
    let len = @huffman.sym_info_code_length(codelen_encoder.get(sym))
    writer.write_bits(len, 3)
  }
  
  for i = 0; i < sym_count; i = i + 1 {
    let sym_with_extra = codelen_syms[i]
    let sym = sym_with_extra & 0xFF
    let extra_bits = sym_with_extra >> 8
    
    let info = codelen_encoder.get(sym)
    let code = @huffman.sym_info_code(info)
    let code_len = @huffman.sym_info_code_length(info)
    
    writer.write_bits(code, code_len)
    
    if sym == 16 {
      writer.write_bits(extra_bits, 2)
    } else if sym == 17 {
      writer.write_bits(extra_bits, 3)
    } else if sym == 18 {
      writer.write_bits(extra_bits, 7)
    }
  }
}

/// Convert a match length to symbol
pub fn length_to_symbol(length : Int) -> Int {
  if length <= 10 {
    257 + (length - 3)
  } else if length <= 18 {
    265 + ((length - 11) / 2)
  } else if length <= 34 {
    269 + ((length - 19) / 4)
  } else if length <= 66 {
    273 + ((length - 35) / 8)
  } else if length <= 130 {
    277 + ((length - 67) / 16)
  } else if length <= 257 {
    281 + ((length - 131) / 32)
  } else {
    285
  }
}

/// Convert a distance to symbol
pub fn distance_to_symbol(dist : Int) -> Int {
  if dist <= 4 {
    dist - 1
  } else if dist <= 8 {
    4 + ((dist - 5) >> 1)
  } else if dist <= 16 {
    6 + ((dist - 9) >> 2)
  } else if dist <= 32 {
    8 + ((dist - 17) >> 3)
  } else if dist <= 64 {
    10 + ((dist - 33) >> 4)
  } else if dist <= 128 {
    12 + ((dist - 65) >> 5)
  } else if dist <= 256 {
    14 + ((dist - 129) >> 6)
  } else if dist <= 512 {
    16 + ((dist - 257) >> 7)
  } else if dist <= 1024 {
    18 + ((dist - 513) >> 8)
  } else if dist <= 2048 {
    20 + ((dist - 1025) >> 9)
  } else if dist <= 4096 {
    22 + ((dist - 2049) >> 10)
  } else if dist <= 8192 {
    24 + ((dist - 4097) >> 11)
  } else if dist <= 16384 {
    26 + ((dist - 8193) >> 12)
  } else {
    28 + ((dist - 16385) >> 13)
  }
}

/// Write a literal or end-of-block symbol
pub fn write_literal_symbol(
  writer : BitWriter,
  encoder : HuffmanEncoder,
  symbol : Int,
) -> Unit {
  let info = encoder.get(symbol)
  let code = @huffman.sym_info_code(info)
  let len = @huffman.sym_info_code_length(info)
  writer.write_bits(code, len)
}

/// Write a length/distance pair
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
  let len_code = @huffman.sym_info_code(len_info)
  let len_code_len = @huffman.sym_info_code_length(len_info)
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
  let dist_code = @huffman.sym_info_code(dist_info)
  let dist_code_len = @huffman.sym_info_code_length(dist_info)
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

/// Frequency counter for dynamic Huffman
pub struct FrequencyCounter {
  litlen_freqs : Array[Int]
  dist_freqs : Array[Int]
}

pub fn FrequencyCounter::new() -> FrequencyCounter {
  { litlen_freqs: Array::make(286, 0), dist_freqs: Array::make(30, 0) }
}

pub fn FrequencyCounter::add_literal(self : FrequencyCounter, lit : Int) -> Unit {
  self.litlen_freqs[lit] = self.litlen_freqs[lit] + 1
}

pub fn FrequencyCounter::add_length(self : FrequencyCounter, length : Int) -> Unit {
  let sym = length_to_symbol(length)
  self.litlen_freqs[sym] = self.litlen_freqs[sym] + 1
}

pub fn FrequencyCounter::add_distance(self : FrequencyCounter, dist : Int) -> Unit {
  let sym = distance_to_symbol(dist)
  self.dist_freqs[sym] = self.dist_freqs[sym] + 1
}

pub fn FrequencyCounter::add_end_of_block(self : FrequencyCounter) -> Unit {
  self.litlen_freqs[256] = 1
}

/// Deflate with fixed Huffman (literals only, no LZ77)
pub fn deflate_fixed_literals_only(
  bytes : Bytes,
  start : Int,
  len : Int,
  is_final : Bool,
) -> Bytes {
  let output = @buffer.ByteBuf::new(len * 2, false)
  let writer = @bitstream.BitWriter::new(output)
  
  let header = if is_final { 0b011 } else { 0b010 }
  writer.write_bits(header, 3)
  
  for i = 0; i < len; i = i + 1 {
    let byte = bytes[start + i].to_int()
    write_literal_symbol(writer, @huffman.fixed_litlen_encoder, byte)
  }
  
  write_literal_symbol(writer, @huffman.fixed_litlen_encoder, litlen_end_of_block_sym)
  
  writer.flush()
  output.contents()
}

/// Deflate with LZ77 + Fixed Huffman
pub fn deflate_fixed(
  bytes : Bytes,
  start : Int,
  len : Int,
  is_final : Bool,
  good_match : Int,
  max_chain : Int
) -> Bytes {
  if len == 0 {
    let output = @buffer.ByteBuf::new(10, false)
    let writer = @bitstream.BitWriter::new(output)
    let header = if is_final { 0b011 } else { 0b010 }
    writer.write_bits(header, 3)
    write_literal_symbol(writer, @huffman.fixed_litlen_encoder, litlen_end_of_block_sym)
    writer.flush()
    return output.contents()
  }
  
  let hash_head = Array::make(@lz77.hash_size, @lz77.no_pos)
  let hash_prev = Array::make(@lz77.window_size, 0)
  
  let output = @buffer.ByteBuf::new(len * 2, false)
  let writer = @bitstream.BitWriter::new(output)
  
  let header = if is_final { 0b011 } else { 0b010 }
  writer.write_bits(header, 3)
  
  let max_pos = start + len - @lz77.min_match_len
  
  fn compress_loop(pos : Int, prev_bref : Int) -> Unit {
    if pos > max_pos {
      let prev_len = @lz77.backref_len(prev_bref)
      let final_pos = if prev_len == 0 {
        pos
      } else {
        let dist = @lz77.backref_dist(prev_bref)
        write_length_distance(writer, @huffman.fixed_litlen_encoder, @huffman.fixed_dist_encoder, prev_len, dist)
        pos - 1 + prev_len
      }
      
      let end = start + len
      for i = final_pos; i < end; i = i + 1 {
        let byte = bytes[i].to_int()
        write_literal_symbol(writer, @huffman.fixed_litlen_encoder, byte)
      }
      
      write_literal_symbol(writer, @huffman.fixed_litlen_encoder, litlen_end_of_block_sym)
    } else {
      if pos + 4 > start + len {
        if prev_bref > 0 {
          let prev_len = @lz77.backref_len(prev_bref)
          let dist = @lz77.backref_dist(prev_bref)
          write_length_distance(writer, @huffman.fixed_litlen_encoder, @huffman.fixed_dist_encoder, prev_len, dist)
          compress_loop(pos - 1 + prev_len, 0)
        } else {
          let byte = bytes[pos].to_int()
          write_literal_symbol(writer, @huffman.fixed_litlen_encoder, byte)
          compress_loop(pos + 1, 0)
        }
        return
      }
      
      let hash = @lz77.hash4(bytes, pos)
      let max_match = (start + len - pos).min(@lz77.max_match_len)
      let prev_len = @lz77.backref_len(prev_bref)
      
      let cur_bref = @lz77.find_backref(
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
      let cur_len = @lz77.backref_len(cur_bref)
      
      @lz77.insert_hash(hash_head, hash_prev, hash, pos)
      
      if prev_len > 0 && prev_len >= cur_len {
        let dist = @lz77.backref_dist(prev_bref)
        write_length_distance(writer, @huffman.fixed_litlen_encoder, @huffman.fixed_dist_encoder, prev_len, dist)
        
        let next = pos - 1 + prev_len
        let last = (next - 1).min(max_pos)
        for j = pos + 1; j <= last; j = j + 1 {
          if j + 3 < start + len {
            let h = @lz77.hash4(bytes, j)
            @lz77.insert_hash(hash_head, hash_prev, h, j)
          }
        }
        
        compress_loop(next, 0)
      } else if cur_len == 0 {
        if prev_len > 0 {
          let byte = bytes[pos - 1].to_int()
          write_literal_symbol(writer, @huffman.fixed_litlen_encoder, byte)
        } else {
          let byte = bytes[pos].to_int()
          write_literal_symbol(writer, @huffman.fixed_litlen_encoder, byte)
        }
        compress_loop(pos + 1, 0)
      } else {
        if prev_len > 0 {
          let byte = bytes[pos - 1].to_int()
          write_literal_symbol(writer, @huffman.fixed_litlen_encoder, byte)
        }
        compress_loop(pos + 1, cur_bref)
      }
    }
  }
  
  compress_loop(start, 0)
  writer.flush()
  output.contents()
}

/// Deflate with LZ77 + Dynamic Huffman
pub fn deflate_dynamic(
  bytes : Bytes,
  start : Int,
  len : Int,
  is_final : Bool,
  good_match : Int,
  max_chain : Int
) -> Bytes {
  if len == 0 {
    let output = @buffer.ByteBuf::new(10, false)
    let writer = @bitstream.BitWriter::new(output)
    let header = if is_final { 0b011 } else { 0b010 }
    writer.write_bits(header, 3)
    write_literal_symbol(writer, @huffman.fixed_litlen_encoder, litlen_end_of_block_sym)
    writer.flush()
    return output.contents()
  }
  
  // Step 1: Run LZ77 and collect frequencies
  let hash_head = Array::make(@lz77.hash_size, @lz77.no_pos)
  let hash_prev = Array::make(@lz77.window_size, 0)
  let freqs = FrequencyCounter::new()
  
  let max_symbols = len + 1000
  let symbols = Array::make(max_symbols, 0)
  let mut sym_idx = 0
  
  let max_pos = start + len - @lz77.min_match_len
  
  fn compress_and_count(pos : Int, prev_bref : Int) -> Unit {
    if pos > max_pos {
      let prev_len = @lz77.backref_len(prev_bref)
      let final_pos = if prev_len == 0 {
        pos
      } else {
        let dist = @lz77.backref_dist(prev_bref)
        freqs.add_length(prev_len)
        freqs.add_distance(dist)
        symbols[sym_idx] = prev_bref
        sym_idx = sym_idx + 1
        pos - 1 + prev_len
      }
      
      let end = start + len
      for i = final_pos; i < end; i = i + 1 {
        let byte = bytes[i].to_int()
        freqs.add_literal(byte)
        symbols[sym_idx] = byte
        sym_idx = sym_idx + 1
      }
      
      freqs.add_end_of_block()
    } else {
      if pos + 4 > start + len {
        if prev_bref > 0 {
          let prev_len = @lz77.backref_len(prev_bref)
          let dist = @lz77.backref_dist(prev_bref)
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
      
      let hash = @lz77.hash4(bytes, pos)
      let max_match = (start + len - pos).min(@lz77.max_match_len)
      let prev_len = @lz77.backref_len(prev_bref)
      
      let cur_bref = @lz77.find_backref(
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
      let cur_len = @lz77.backref_len(cur_bref)
      
      @lz77.insert_hash(hash_head, hash_prev, hash, pos)
      
      if prev_len > 0 && prev_len >= cur_len {
        let dist = @lz77.backref_dist(prev_bref)
        freqs.add_length(prev_len)
        freqs.add_distance(dist)
        symbols[sym_idx] = prev_bref
        sym_idx = sym_idx + 1
        
        let next = pos - 1 + prev_len
        let last = (next - 1).min(max_pos)
        for j = pos + 1; j <= last; j = j + 1 {
          if j + 3 < start + len {
            let h = @lz77.hash4(bytes, j)
            @lz77.insert_hash(hash_head, hash_prev, h, j)
          }
        }
        
        compress_and_count(next, 0)
      } else if cur_len == 0 {
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
  
  // Step 2: Build Huffman trees
  let litlen_lengths = build_optimal_code_lengths(freqs.litlen_freqs, 285, 15)
  let litlen_encoder = build_canonical_huffman(litlen_lengths, 285)
  
  let mut litlen_max = 285
  while litlen_max > 256 && litlen_lengths[litlen_max] == 0 {
    litlen_max = litlen_max - 1
  }
  let hlit = (litlen_max + 1) - 257
  
  let dist_lengths = build_optimal_code_lengths(freqs.dist_freqs, 29, 15)
  let mut dist_encoder = build_canonical_huffman(dist_lengths, 29)
  
  let mut dist_max = 29
  while dist_max > 0 && dist_lengths[dist_max] == 0 {
    dist_max = dist_max - 1
  }
  
  let hdist = if dist_max == 0 && dist_lengths[0] == 0 {
    dist_lengths[0] = 1
    dist_encoder = @huffman.HuffmanEncoder::new()
    dist_encoder.set(0, @huffman.sym_info_make(0, 1))
    0
  } else {
    (dist_max + 1) - 1
  }
  
  // Step 3: Encode code lengths
  let (codelen_syms, codelen_freqs, codelen_count) = encode_code_lengths(
    litlen_lengths,
    dist_lengths,
    hlit,
    hdist
  )
  
  // Step 4: Build codelen tree
  let codelen_lengths = build_optimal_code_lengths(codelen_freqs, 18, 7)
  let codelen_encoder = build_canonical_huffman(codelen_lengths, 18)
  
  // Step 5: Write dynamic block
  let output = @buffer.ByteBuf::new(len * 2, false)
  let writer = @bitstream.BitWriter::new(output)
  
  let header = if is_final { 0b101 } else { 0b100 }
  writer.write_bits(header, 3)
  
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
  
  // Step 6: Write symbols
  for i = 0; i < sym_idx; i = i + 1 {
    let sym = symbols[i]
    let dist = @lz77.backref_dist(sym)
    
    if dist == 0 {
      let lit = @lz77.backref_len(sym)
      write_literal_symbol(writer, litlen_encoder, lit)
    } else {
      let length = @lz77.backref_len(sym)
      write_length_distance(writer, litlen_encoder, dist_encoder, length, dist)
    }
  }
  
  write_literal_symbol(writer, litlen_encoder, litlen_end_of_block_sym)
  
  writer.flush()
  output.contents()
}
