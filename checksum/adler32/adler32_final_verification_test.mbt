// Final verification test for Adler-32 - Direct comparison with Python's zlib.adler32
// This test ensures our Adler-32 implementation is 100% compatible with Python

///|
/// Complete verification against Python's zlib.adler32 - All common test cases
test "adler32_complete_python_verification" {
  // Empty data
  let adler0 = @adler32.bytes_adler32(b"", 0, 0)

  // Single character
  let adler1 = @adler32.bytes_adler32(b"a", 0, 1)

  // Common string
  let adler2 = @adler32.bytes_adler32(b"abc", 0, 3)

  // Hello
  let adler3 = @adler32.bytes_adler32(b"hello", 0, 5)

  // Hello world
  let adler4 = @adler32.bytes_adler32(b"hello world", 0, 11)

  // Numbers
  let adler5 = @adler32.bytes_adler32(b"123456789", 0, 9)

  // Verify all match Python exactly
  @json.inspect([adler0, adler1, adler2, adler3, adler4, adler5], content=[
    1, 6422626, 38600999, 103547413, 436929629, 152961502,
  ])
}

///|
/// Test Adler-32 algorithm fundamentals
test "adler32_algorithm_verification" {
  // Verify Adler-32 base is correct (65521 - largest prime < 65536)
  // Note: We can't access the constant directly, but we can verify behavior

  // Test known single-byte values that verify the algorithm
  let adler_0 = @adler32.bytes_adler32(b"\x00", 0, 1) // byte 0
  let adler_1 = @adler32.bytes_adler32(b"\x01", 0, 1) // byte 1
  let adler_255 = @adler32.bytes_adler32(b"\xff", 0, 1) // byte 255

  // Python verification:
  // zlib.adler32(b"\x00") = 0x00010001 (65537)
  // zlib.adler32(b"\x01") = 0x00020002 (131074)  
  // zlib.adler32(b"\xff") = 0x01000100 (16777472)
  @json.inspect([adler_0, adler_1, adler_255], content=[65537, 131074, 16777472])
}

///|
/// Test Adler-32 state consistency
test "adler32_state_consistency" {
  let initial = @adler32.Adler32::init()
  let empty_result = initial.finish()
  let also_empty = @adler32.bytes_adler32(b"", 0, 0)

  // Both should give the same result (1)
  @json.inspect((empty_result, also_empty, empty_result == also_empty), content=[
    1, 1, true,
  ])
}

///|
/// Test incremental vs direct computation equivalence for complex case
test "adler32_incremental_equivalence" {
  let test_string = b"Hello, World! This is a longer test string."
  let len = test_string.length()

  // Direct computation
  let direct = @adler32.bytes_adler32(test_string, 0, len)

  // Incremental computation (split at multiple points)
  let incr1 = @adler32.Adler32::init()
    .update_bytes(test_string[0:13]) // "Hello, World!"
    .update_bytes(test_string[13:len]) // Rest
    .finish()

  // Three-way split
  let incr2 = @adler32.Adler32::init()
    .update_bytes(test_string[0:5]) // "Hello"
    .update_bytes(test_string[5:13]) // ", World!"
    .update_bytes(test_string[13:len]) // Rest
    .finish()

  // Python: zlib.adler32(b"Hello, World! This is a longer test string.") = 0x42b10f0b (1118899979)
  @json.inspect((direct, incr1, incr2, direct == incr1 && incr1 == incr2), content=[
    1118899979, 1118899979, 1118899979, true,
  ])
}

///|
/// Test Adler-32 with overflow conditions (large block processing)
test "adler32_large_data_handling" {
  // Test processing data that would require modulo operations
  // Create data that will trigger the modulo operations in the algorithm
  let mut adler = @adler32.Adler32::init()

  // Add 1000 times the character 'Z' (ASCII 90)
  // This creates large s1 and s2 values that need modulo reduction
  for i = 0; i < 1000; i = i + 1 {
    adler = adler.update_bytes(b"Z"[0:1])
  }
  let result = adler.finish()

  // Python: zlib.adler32(b"Z" * 1000) = 0x81315fa0 (2167496608)
  @json.inspect(result, content=2167496608)
}
