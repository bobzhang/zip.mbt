// Checksum tests (CRC-32, Adler-32)

///|
/// CRC-32 tests
test "crc32_empty" {
  let crc = bytes_crc32(b"", 0, 0)
  @json.inspect((crc, crc == 0), content=[0, true])
}

///|
test "crc32_simple" {
  let data = b"hello world"
  let crc = bytes_crc32(data, 0, data.length())
  // CRC-32 of "hello world" should be 0x0d4a1185 (222957317 in decimal)
  @json.inspect(crc, content=222957957)
}

///|
test "crc32_incremental" {
  let data = b"hello world"
  let crc1 = Crc32::init()
    .update_bytes(data, 0, 5) // "hello"
    .update_bytes(data, 5, 6) // " world"
    .finish()
  let crc2 = bytes_crc32(data, 0, data.length())
  @json.inspect((crc1 == crc2, crc1), content=[true, 222957957])
}

///|
/// Adler-32 tests
test "adler32_empty" {
  let adler = bytes_adler32(b"", 0, 0)
  @json.inspect((adler, adler == 1), content=[1, true])
}

///|
test "adler32_simple" {
  let data = b"hello world"
  let adler = bytes_adler32(data, 0, data.length())
  // Adler-32 of "hello world" should be 0x26e4023c (651924540 in decimal)
  @json.inspect(adler, content=436929629)
}

///|
test "adler32_incremental" {
  let data = b"hello world"
  let adler1 = Adler32::init()
    .update_bytes(data, 0, 5) // "hello"
    .update_bytes(data, 5, 6) // " world"
    .finish()
  let adler2 = bytes_adler32(data, 0, data.length())
  @json.inspect((adler1 == adler2, adler1), content=[true, 436929629])
}

///|
/// Check functions
test "crc32_check_success" {
  let result = check_crc32(0x12345678, 0x12345678)
  @json.inspect(result, content={ "Ok": null })
}

///|
test "crc32_check_failure" {
  let result = check_crc32(0x12345678, 0x87654321)
  match result {
    Ok(_) => @json.inspect("should not succeed", content="\"mismatch\"")
    Err(msg) => @json.inspect(msg.contains("mismatch"), content=true)
  }
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

///|
/// Test inflate with CRC-32 computation
test "inflate_with_crc32" {
  // Same uncompressed block as above
  let compressed = Bytes::from_fixedarray([
    0b00000001, // final=1, type=00 (uncompressed)
     3, 0, // length = 3
     252, 255, // ~length
     0x41, 0x42, 0x43, // "ABC"
  ])
  let (result, crc) = inflate_and_crc32(
    compressed,
    0,
    compressed.length(),
    None,
  )
  // Verify data and that CRC is computed
  @json.inspect(
    (result[0].to_int(), result[1].to_int(), result[2].to_int(), crc > 0),
    content=[65, 66, 67, true],
  )
}

///|
/// Fpath tests

///|
test "format_file_mode" {
  // 0o755 = rwxr-xr-x
  @json.inspect(format_file_mode(0o755), content="rwxr-xr-x")
  // 0o644 = rw-r--r--
  @json.inspect(format_file_mode(0o644), content="rw-r--r--")
}

///|
/// End-to-End Compatibility Tests
/// These tests verify exact compatibility with the OCaml zipc library
test "e2e_crc32_known_value" {
  // Test vector from OCaml zipc: "The quick brown fox jumps over the lazy dog"
  let test_string = b"The quick brown fox jumps over the lazy dog"
  let crc = bytes_crc32(test_string, 0, test_string.length())
  // Expected: 0x414FA339 (from OCaml test)
  @json.inspect(crc, content=1095738169)
}

///|
test "e2e_adler32_known_value" {
  // Test vector from OCaml zipc
  let test_string = b"The quick brown fox jumps over the lazy dog"
  let adler = bytes_adler32(test_string, 0, test_string.length())
  // Expected: 0x5bdc0fda (from OCaml test)
  @json.inspect(adler, content=1541148634)
}

///|
test "crc32_and_deflate_api" {
  let data = b"Test CRC-32 with deflate"
  match crc32_and_deflate(data, 0, data.length(), None) {
    Ok((crc, compressed)) => {
      // CRC should match direct calculation
      let expected_crc = bytes_crc32(data, 0, data.length())
      @json.inspect(crc == expected_crc, content=true)

      // Compressed data should be valid
      let decompressed = inflate(
        compressed,
        0,
        compressed.length(),
        Some(data.length()),
      )
      @json.inspect(decompressed.length(), content=24)
    }
    Err(_) => @json.inspect("should not fail", content="success")
  }
}

///|
test "adler32_and_deflate_api" {
  let data = b"Test Adler-32 with deflate"
  match adler32_and_deflate(data, 0, data.length(), None) {
    Ok((adler, compressed)) => {
      // Adler-32 should match direct calculation
      let expected_adler = bytes_adler32(data, 0, data.length())
      @json.inspect(adler == expected_adler, content=true)

      // Compressed data should be valid
      let decompressed = inflate(
        compressed,
        0,
        compressed.length(),
        Some(data.length()),
      )
      @json.inspect(decompressed.length(), content=26)
    }
    Err(_) => @json.inspect("should not fail", content="success")
  }
}

// ============================================================================
// Additional coverage tests for error paths and edge cases
// ============================================================================

///|
/// Test inflate_and_adler32
test "coverage_inflate_adler32" {
  let data = b"Inflate with Adler-32"
  let compressed = deflate_fixed(data, 0, data.length(), true, 8, 128)
  let (dec, adler) = inflate_and_adler32(
    compressed,
    0,
    compressed.length(),
    Some(data.length()),
  )
  @json.inspect((dec == data, adler == bytes_adler32(data, 0, data.length())), content=[
    true, true,
  ])
}
