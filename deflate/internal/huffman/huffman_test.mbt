///|
/// Huffman decoder tests
test "huffman_decoder_creation" {
  let decoder = @huffman.HuffmanDecoder::new()
  @json.inspect(
    (decoder.counts_length(), decoder.symbols_length(), decoder.max_sym()),
    content=[16, 288, 0],
  )
}

///|
test "fixed_litlen_decoder_setup" {
  // Check that fixed literal/length decoder is properly initialized
  @json.inspect(
    (
      @huffman.fixed_litlen_decoder.count(7), // 256-279: 24 symbols
      @huffman.fixed_litlen_decoder.count(8), // 0-143 + 280-287: 152 symbols
      @huffman.fixed_litlen_decoder.count(9), // 144-255: 112 symbols
      @huffman.fixed_litlen_decoder.max_sym(),
    ),
    content=[24, 152, 112, 285],
  )
}

///|
test "fixed_dist_decoder_setup" {
  @json.inspect(
    (
      @huffman.fixed_dist_decoder.count(5),
      @huffman.fixed_dist_decoder.max_sym(),
    ),
    content=[32, 29],
  )
}

///|
/// Huffman encoder tests
test "huffman_encoder_creation" {
  let encoder = @huffman.HuffmanEncoder::new()
  @json.inspect((encoder.codes_length(), encoder.max_sym()), content=[288, 0])
}

///|
test "huffman_encoder_set_get" {
  let encoder = @huffman.HuffmanEncoder::new()
  // Set code for symbol 65 ('A'): code=0b101, length=3
  let info = @huffman.sym_info_make(0b101, 3)
  encoder.set(65, info)
  let retrieved = encoder.get(65)
  @json.inspect(
    (
      @huffman.sym_info_code(retrieved),
      @huffman.sym_info_code_length(retrieved),
      encoder.max_sym(),
    ),
    content=[5, 3, 65],
  )
}

///|
test "fixed_litlen_encoder_symbols" {
  // Test a few key symbols from fixed Huffman table
  // Symbol 0: 8 bits
  let info0 = @huffman.fixed_litlen_encoder.get(0)
  @json.inspect(@huffman.sym_info_code_length(info0), content=8)

  // Symbol 143: 8 bits (last of 0-143 range)
  let info143 = @huffman.fixed_litlen_encoder.get(143)
  @json.inspect(@huffman.sym_info_code_length(info143), content=8)

  // Symbol 144: 9 bits (first of 144-255 range)
  let info144 = @huffman.fixed_litlen_encoder.get(144)
  @json.inspect(@huffman.sym_info_code_length(info144), content=9)

  // Symbol 256: 7 bits (end-of-block, first of 256-279 range)
  let info256 = @huffman.fixed_litlen_encoder.get(256)
  @json.inspect(@huffman.sym_info_code_length(info256), content=7)

  // Symbol 280: 8 bits (first of 280-287 range)
  let info280 = @huffman.fixed_litlen_encoder.get(280)
  @json.inspect(@huffman.sym_info_code_length(info280), content=8)
}

///|
test "fixed_dist_encoder_symbols" {
  // All distance symbols should be 5 bits
  let info0 = @huffman.fixed_dist_encoder.get(0)
  @json.inspect(@huffman.sym_info_code_length(info0), content=5)
  let info15 = @huffman.fixed_dist_encoder.get(15)
  @json.inspect(@huffman.sym_info_code_length(info15), content=5)
  let info29 = @huffman.fixed_dist_encoder.get(29)
  @json.inspect(@huffman.sym_info_code_length(info29), content=5)
}

///|
test "reverse_bits" {
  @json.inspect(@huffman.reverse_bits(0b101, 3), content=5) // 101 -> 101 (palindrome)
  @json.inspect(@huffman.reverse_bits(0b1100, 4), content=3) // 1100 -> 0011
  @json.inspect(@huffman.reverse_bits(0b1010, 4), content=5) // 1010 -> 0101
  @json.inspect(@huffman.reverse_bits(0b11111111, 8), content=255) // all ones stays all ones
}

///|
test "sym_info_make_code_length" {
  let info = @huffman.sym_info_make(0b1010, 4)
  @json.inspect(@huffman.sym_info_code(info), content=10)
  @json.inspect(@huffman.sym_info_code_length(info), content=4)
}
