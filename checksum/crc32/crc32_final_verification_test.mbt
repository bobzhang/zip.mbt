// Final verification test - Direct comparison with Python's zlib.crc32
// This test ensures our CRC32 implementation is 100% compatible with Python

///|
/// Complete verification against Python's zlib.crc32 - All common test cases
test "crc32_complete_python_verification" {
  // Empty data
  let crc0 = @crc32.bytes_crc32(b""[:])

  // Single character
  let crc1 = @crc32.bytes_crc32(b"a"[0:1])

  // Common string
  let crc2 = @crc32.bytes_crc32(b"abc"[0:3])

  // Hello
  let crc3 = @crc32.bytes_crc32(b"hello"[0:5])

  // Hello world
  let crc4 = @crc32.bytes_crc32(b"hello world"[0:11])

  // Numbers
  let crc5 = @crc32.bytes_crc32(b"123456789"[0:9])

  // Verify all match Python exactly
  @json.inspect([crc0, crc1, crc2, crc3, crc4, crc5], content=[
    0, 3904355907, 891568578, 907060870, 222957957, 3421780262,
  ])
}

///|
/// Test CRC32 implementation consistency with known values
test "crc32_implementation_details" {
  // Test that specific single bytes produce expected CRC values
  // These verify our table is correctly computed
  let crc_0 = @crc32.bytes_crc32(b"\x00"[0:1])
  let crc_1 = @crc32.bytes_crc32(b"\x01"[0:1])
  let crc_2 = @crc32.bytes_crc32(b"\x02"[0:1])

  // Python: zlib.crc32(b"\x00") = 0xd202ef8d (3523407757)
  // Python: zlib.crc32(b"\x01") = 0xa505df1b (2768625435) 
  // Python: zlib.crc32(b"\x02") = 0x3c0c8ea1 (1007455905)
  @json.inspect([crc_0, crc_1, crc_2], content=[
    3523407757, 2768625435, 1007455905,
  ])
}

///|
/// Test edge case: CRC32 state consistency
test "crc32_state_consistency" {
  let initial = @crc32.Crc32::init()
  let empty_result = initial.finish()
  let also_empty = @crc32.bytes_crc32(b""[:])

  // Both should give the same result (0)
  @json.inspect((empty_result, also_empty, empty_result == also_empty), content=[
    0, 0, true,
  ])
}

///|
/// Test incremental vs direct computation equivalence  
test "crc32_incremental_equivalence" {
  let test_string = b"Hello, World! This is a longer test string."
  let len = test_string.length()

  // Direct computation
  let direct = @crc32.bytes_crc32(test_string[:])

  // Incremental computation (split at multiple points)
  let incr1 = @crc32.Crc32::init()
    .update_bytes(test_string[0:13]) // "Hello, World!"
    .update_bytes(test_string[13:len]) // Rest
    .finish()

  // Byte by byte computation (first 5 chars)
  let mut incr2 = @crc32.Crc32::init()
  for i = 0; i < 5; i = i + 1 {
    incr2 = incr2.update_byte(test_string[i].to_int())
  }
  let incr2_final = incr2.update_bytes(test_string[5:len]).finish()
  @json.inspect(
    (direct, incr1, incr2_final, direct == incr1 && incr1 == incr2_final),
    content=[1700084974, 1700084974, 1700084974, true],
  )
}
