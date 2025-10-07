// Comprehensive Adler-32 tests verified against Python's zlib.adler32
// These test vectors were generated using Python to ensure compatibility

///|
/// Test Adler-32 of empty data (Python verified)
test "adler32_empty_python_verified" {
  let adler = @adler32.bytes_adler32(b"", 0, 0)
  // Python: zlib.adler32(b"") = 0x00000001 (1)
  @json.inspect(adler, content=1)
}

///|
/// Test Adler-32 of single character 'a' (Python verified)
test "adler32_single_a_python_verified" {
  let data = b"a"
  let adler = @adler32.bytes_adler32(data, 0, data.length())
  // Python: zlib.adler32(b"a") = 0x00620062 (6422626)
  @json.inspect(adler, content=6422626)
}

///|
/// Test Adler-32 of single character 'x' (Python verified)
test "adler32_single_x_python_verified" {
  let data = b"x"
  let adler = @adler32.bytes_adler32(data, 0, data.length())
  // Python: zlib.adler32(b"x") = 0x00790079 (7929977)
  @json.inspect(adler, content=7929977)
}

///|
/// Test Adler-32 of "abc" (Python verified)
test "adler32_abc_python_verified" {
  let data = b"abc"
  let adler = @adler32.bytes_adler32(data, 0, data.length())
  // Python: zlib.adler32(b"abc") = 0x024d0127 (38600999)
  @json.inspect(adler, content=38600999)
}

///|
/// Test Adler-32 of "hello" (Python verified)
test "adler32_hello_python_verified" {
  let data = b"hello"
  let adler = @adler32.bytes_adler32(data, 0, data.length())
  // Python: zlib.adler32(b"hello") = 0x062c0215 (103547413)
  @json.inspect(adler, content=103547413)
}

///|
/// Test Adler-32 of "hello world" (Python verified)
test "adler32_hello_world_python_verified" {
  let data = b"hello world"
  let adler = @adler32.bytes_adler32(data, 0, data.length())
  // Python: zlib.adler32(b"hello world") = 0x1a0b045d (436929629)
  @json.inspect(adler, content=436929629)
}

///|
/// Test Adler-32 of "123456789" (Python verified)
test "adler32_numbers_python_verified" {
  let data = b"123456789"
  let adler = @adler32.bytes_adler32(data, 0, data.length())
  // Python: zlib.adler32(b"123456789") = 0x091e01de (152961502)
  @json.inspect(adler, content=152961502)
}

///|
/// Test Adler-32 of "The quick brown fox jumps over the lazy dog" (Python verified)
test "adler32_quick_fox_python_verified" {
  let data = b"The quick brown fox jumps over the lazy dog"
  let adler = @adler32.bytes_adler32(data, 0, data.length())
  // Python: zlib.adler32(b"The quick brown fox jumps over the lazy dog") = 0x5bdc0fda (1541148634)
  @json.inspect(adler, content=1541148634)
}

///|
/// Test incremental Adler-32 computation with "hello world" (Python verified)
test "adler32_incremental_hello_world_python_verified" {
  let data = b"hello world"

  // Compute incrementally: "hello" + " world"
  let adler_incremental = @adler32.Adler32::init()
    .update_bytes(data, 0, 5) // "hello"
    .update_bytes(data, 5, 6) // " world"
    .finish()

  // Compute all at once
  let adler_direct = @adler32.bytes_adler32(data, 0, data.length())

  // Both should match Python's result: 0x1a0b045d (436929629)
  @json.inspect(
    (adler_incremental, adler_direct, adler_incremental == adler_direct),
    content=[436929629, 436929629, true],
  )
}

///|
/// Test incremental Adler-32 computation with "abc" (Python verified)
test "adler32_incremental_abc_python_verified" {
  let data = b"abc"

  // Compute incrementally: "a" + "bc"
  let adler_incremental = @adler32.Adler32::init()
    .update_bytes(data, 0, 1) // "a"
    .update_bytes(data, 1, 2) // "bc"
    .finish()

  // Compute all at once
  let adler_direct = @adler32.bytes_adler32(data, 0, data.length())

  // Both should match Python's result: 0x024d0127 (38600999)
  @json.inspect(
    (adler_incremental, adler_direct, adler_incremental == adler_direct),
    content=[38600999, 38600999, true],
  )
}

///|
/// Test Adler-32 with binary data (Python verified)
test "adler32_binary_data_python_verified" {
  let data = b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f"
  let adler = @adler32.bytes_adler32(data, 0, data.length())
  // Python: zlib.adler32(bytes([0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15])) = 0x02b80079 (45613177)
  @json.inspect(adler, content=45613177)
}

///|
/// Test Adler-32 partial data computation (Python verified)
test "adler32_partial_data_python_verified" {
  let data = b"hello world"

  // Test "hello" part (first 5 bytes)
  let adler_hello = @adler32.bytes_adler32(data, 0, 5)
  // Python: zlib.adler32(b"hello") = 0x062c0215 (103547413)

  // Test "world" part (last 5 bytes, skipping space)
  let adler_world = @adler32.bytes_adler32(data, 6, 5)
  // Python: zlib.adler32(b"world") = 0x06a60229 (111542825)

  @json.inspect((adler_hello, adler_world), content=[103547413, 111542825])
}

///|
/// Test Adler-32 state initialization and finalization (Python verified)
test "adler32_init_finish_python_verified" {
  // Empty computation should give 1
  let adler_empty = @adler32.Adler32::init().finish()
  @json.inspect(adler_empty, content=1)

  // Single byte computation matches manual calculation
  let adler_a = @adler32.Adler32::init().update_bytes(b"a", 0, 1).finish()
  // Python: zlib.adler32(b"a") = 0x00620062 (6422626)
  @json.inspect(adler_a, content=6422626)
}

///|
/// Test Adler-32 with large repeated data (Python verified)
test "adler32_large_repeated_python_verified" {
  // Test incremental computation of 100 'A' characters
  let mut adler = @adler32.Adler32::init()
  for i = 0; i < 100; i = i + 1 {
    adler = adler.update_bytes(b"A", 0, 1)
  }
  let result = adler.finish()

  // Python: zlib.adler32(b"A" * 100) = 0x02e91965 (48830821)
  @json.inspect(result, content=48830821)
}

///|
/// Test Adler-32 edge cases: start and length parameters
test "adler32_edge_cases_python_verified" {
  let data = b"hello world"

  // Test different substrings
  let adler_hell = @adler32.bytes_adler32(data, 0, 4) // "hell"
  let adler_ello = @adler32.bytes_adler32(data, 1, 4) // "ello"
  let adler_space_world = @adler32.bytes_adler32(data, 5, 6) // " world"

  // Python verification:
  // zlib.adler32(b"hell") = 0x041701a6 (68616614)
  // zlib.adler32(b"ello") = 0x042301ad (69403053)
  // zlib.adler32(b" world") = 0x07670249 (124191305)

  @json.inspect((adler_hell, adler_ello, adler_space_world), content=[
    68616614, 69403053, 124191305,
  ])
}
