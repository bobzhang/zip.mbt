// Tests for zipc MoonBit port

///|
/// CRC-32 tests
test "crc32_empty" {
  let crc = bytes_crc32(b"", 0, 0)
  @json.inspect((crc, crc == 0L), content=["0", true])
}

///|
test "crc32_simple" {
  let data = b"hello world"
  let crc = bytes_crc32(data, 0, data.length())
  // CRC-32 of "hello world" should be 0x0d4a1185 (222957317 in decimal)
  @json.inspect(crc, content="222957957")
}

///|
test "crc32_incremental" {
  let data = b"hello world"
  let crc1 = Crc32::init()
    .update_bytes(data, 0, 5) // "hello"
    .update_bytes(data, 5, 6) // " world"
    .finish()
  let crc2 = bytes_crc32(data, 0, data.length())
  @json.inspect((crc1 == crc2, crc1), content=[true, "222957957"])
}

///|
/// Adler-32 tests
test "adler32_empty" {
  let adler = bytes_adler32(b"", 0, 0)
  @json.inspect((adler, adler == 1L), content=["1", true])
}

///|
test "adler32_simple" {
  let data = b"hello world"
  let adler = bytes_adler32(data, 0, data.length())
  // Adler-32 of "hello world" should be 0x26e4023c (651924540 in decimal)
  @json.inspect(adler, content="436929629")
}

///|
test "adler32_incremental" {
  let data = b"hello world"
  let adler1 = Adler32::init()
    .update_bytes(data, 0, 5) // "hello"
    .update_bytes(data, 5, 6) // " world"
    .finish()
  let adler2 = bytes_adler32(data, 0, data.length())
  @json.inspect((adler1 == adler2, adler1), content=[true, "436929629"])
}

///|
/// Check functions
test "crc32_check_success" {
  let result = check_crc32(0x12345678L, 0x12345678L)
  @json.inspect(result, content={ "Ok": null })
}

///|
test "crc32_check_failure" {
  let result = check_crc32(0x12345678L, 0x87654321L)
  match result {
    Ok(_) => @json.inspect("should not succeed", content="\"mismatch\"")
    Err(msg) => @json.inspect(msg.contains("mismatch"), content=true)
  }
}

///|
/// Huffman decoder tests
test "huffman_decoder_creation" {
  let decoder = HuffmanDecoder::new()
  @json.inspect(
    (decoder.counts.length(), decoder.symbols.length(), decoder.max_sym),
    content=[16, 288, 0],
  )
}

///|
test "fixed_litlen_decoder_setup" {
  // Check that fixed literal/length decoder is properly initialized
  @json.inspect(
    (
      fixed_litlen_decoder.counts[7], // 256-279: 24 symbols
      fixed_litlen_decoder.counts[8], // 0-143 + 280-287: 152 symbols
      fixed_litlen_decoder.counts[9], // 144-255: 112 symbols
      fixed_litlen_decoder.max_sym,
    ),
    content=[24, 152, 112, 285],
  )
}

///|
test "fixed_dist_decoder_setup" {
  // Check that fixed distance decoder is properly initialized
  @json.inspect((fixed_dist_decoder.counts[5], fixed_dist_decoder.max_sym), content=[
    32, 29,
  ])
}

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
test "distance_value_table" {
  // Test a few entries from the distance value table
  // Symbol 0 -> distance 1, 0 extra bits
  @json.inspect(dist_value_of_sym[0], content=16) // 1 << 4
  // Symbol 4 -> distance 5, 1 extra bit
  @json.inspect(dist_value_of_sym[4], content=81) // (5 << 4) | 1
  // Symbol 29 -> distance 24577, 13 extra bits
  @json.inspect(dist_value_of_sym[29], content=393245) // (24577 << 4) | 13
}
