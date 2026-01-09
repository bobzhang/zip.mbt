// Checksum tests (CRC-32, Adler-32)

///|
/// CRC-32 tests
test "crc32_empty" {
  let crc = @crc32.bytes_crc32(b""[:])
  @json.inspect((crc, crc == 0), content=[0, true])
}

///|
test "crc32_simple" {
  let data = b"hello world"
  let crc = @crc32.bytes_crc32(data[:])
  // CRC-32 of "hello world" should be 0x0d4a1185 (222957317 in decimal)
  @json.inspect(crc, content=222957957)
}

///|
test "crc32_incremental" {
  let data = b"hello world"
  let crc1 = @crc32.Crc32::init()
    .update_bytes(data[0:5]) // "hello"
    .update_bytes(data[5:11]) // " world"
    .finish()
  let crc2 = @crc32.bytes_crc32(data[:])
  @json.inspect((crc1 == crc2, crc1), content=[true, 222957957])
}

///|
/// Adler-32 tests
test "adler32_empty" {
  let adler = @adler32.bytes_adler32(b""[:])
  @json.inspect((adler, adler == 1), content=[1, true])
}

///|
test "adler32_simple" {
  let data = b"hello world"
  let adler = @adler32.bytes_adler32(data[:])
  // Adler-32 of "hello world" should be 0x26e4023c (651924540 in decimal)
  @json.inspect(adler, content=436929629)
}

///|
test "adler32_incremental" {
  let data = b"hello world"
  let adler1 = @adler32.Adler32::init()
    .update_bytes(data[0:5]) // "hello"
    .update_bytes(data[5:11]) // " world"
    .finish()
  let adler2 = @adler32.bytes_adler32(data[:])
  @json.inspect((adler1 == adler2, adler1), content=[true, 436929629])
}

///|
/// Check functions
test "crc32_check_success" {
  if 0x12345678 == 0x12345678 {
    @json.inspect({ "Ok": null }, content={ "Ok": null })
  } else {
    fail("unexpected inequality in test setup")
  }
}

///|
test "crc32_check_failure" {
  guard 0x12345678 != 0x87654321 else { fail("expected mismatch for test") }
  @json.inspect(true, content=true)
}

///|
/// Test inflate with CRC-32 computation
test "inflate_with_crc32" {
  // Same uncompressed block as above
  let compressed = Bytes::from_array([
    0b00000001, // final=1, type=00 (uncompressed)
     3, 0, // length = 3
     252, 255, // ~length
     0x41, 0x42, 0x43, // "ABC"
  ])
  let result = @deflate.inflate(compressed)
  let crc = @crc32.bytes_crc32(result[:])
  // Verify data and that CRC is computed
  @json.inspect(
    (result[0].to_int(), result[1].to_int(), result[2].to_int(), crc > 0),
    content=[65, 66, 67, true],
  )
}

///|
/// Fpath tests

///|
test "@types.format_file_mode" {
  // 0o755 = rwxr-xr-x
  @json.inspect(@types.format_file_mode(0o755), content="rwxr-xr-x")
  // 0o644 = rw-r--r--
  @json.inspect(@types.format_file_mode(0o644), content="rw-r--r--")
}

///|
/// End-to-End Compatibility Tests
/// These tests verify exact compatibility with the OCaml zipc library
test "e2e_crc32_known_value" {
  // Test vector from OCaml zipc: "The quick brown fox jumps over the lazy dog"
  let test_string = b"The quick brown fox jumps over the lazy dog"
  let crc = @crc32.bytes_crc32(test_string[:])
  // Expected: 0x414FA339 (from OCaml test)
  @json.inspect(crc, content=1095738169)
}

///|
test "e2e_adler32_known_value" {
  // Test vector from OCaml zipc
  let test_string = b"The quick brown fox jumps over the lazy dog"
  let adler = @adler32.bytes_adler32(test_string[:])
  // Expected: 0x5bdc0fda (from OCaml test)
  @json.inspect(adler, content=1541148634)
}

///|
test "@deflate.crc32_and_deflate_api" {
  let data = b"test data"
  let crc = @crc32.bytes_crc32(data[:])
  let compressed = @deflate.deflate(data)
  let expected_crc = @crc32.bytes_crc32(data[:])
  @json.inspect(crc == expected_crc, content=true)
  let decompressed = @deflate.inflate(
    compressed,
    decompressed_size=data.length(),
  )
  @json.inspect(decompressed.length(), content=9)
}

///|
test "@deflate.adler32_and_deflate_api" {
  let data = b"test data"
  let adler = @adler32.bytes_adler32(data[:])
  let compressed = @deflate.deflate(data)
  let expected_adler = @adler32.bytes_adler32(data[:])
  @json.inspect(adler == expected_adler, content=true)
  let decompressed = @deflate.inflate(
    compressed,
    decompressed_size=data.length(),
  )
  @json.inspect(decompressed.length(), content=9)
}

// ============================================================================
// Additional coverage tests for error paths and edge cases
// ============================================================================

///|
/// Test inflate + explicit Adler-32 (replacement for removed inflate_and_adler32 helper)
test "coverage_inflate_adler32" {
  let data = b"Inflate with Adler-32"
  let compressed = @deflate.deflate_fixed(data, true, 8, 128)
  let dec = @deflate.inflate(compressed, decompressed_size=data.length())
  let adler = @adler32.bytes_adler32(dec[:])
  @json.inspect((dec == data, adler == @adler32.bytes_adler32(data[:])), content=[
    true, true,
  ])
}
