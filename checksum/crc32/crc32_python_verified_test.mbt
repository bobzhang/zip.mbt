// Comprehensive CRC-32 tests verified against Python's zlib.crc32
// These test vectors were generated using Python to ensure compatibility

///|
/// Test CRC-32 of empty data (Python verified)
test "crc32_empty_python_verified" {
  let crc = @crc32.bytes_crc32(b""[:])
  // Python: zlib.crc32(b"") = 0x00000000 (0)
  @json.inspect(crc, content=0)
}

///|
/// Test CRC-32 of single character (Python verified)
test "crc32_single_char_python_verified" {
  let data = b"a"
  let crc = @crc32.bytes_crc32(data[:])
  // Python: zlib.crc32(b"a") = 0xe8b7be43 (3904355907)
  @json.inspect(crc, content=3904355907)
}

///|
/// Test CRC-32 of "abc" (Python verified)
test "crc32_abc_python_verified" {
  let data = b"abc"
  let crc = @crc32.bytes_crc32(data[:])
  // Python: zlib.crc32(b"abc") = 0x352441c2 (891568578)
  @json.inspect(crc, content=891568578)
}

///|
/// Test CRC-32 of "hello" (Python verified)
test "crc32_hello_python_verified" {
  let data = b"hello"
  let crc = @crc32.bytes_crc32(data[:])
  // Python: zlib.crc32(b"hello") = 0x3610a686 (907060870)
  @json.inspect(crc, content=907060870)
}

///|
/// Test CRC-32 of "hello world" (Python verified)
test "crc32_hello_world_python_verified" {
  let data = b"hello world"
  let crc = @crc32.bytes_crc32(data[:])
  // Python: zlib.crc32(b"hello world") = 0x0d4a1185 (222957957)
  @json.inspect(crc, content=222957957)
}

///|
/// Test CRC-32 of "123456789" (Python verified)
test "crc32_numbers_python_verified" {
  let data = b"123456789"
  let crc = @crc32.bytes_crc32(data[:])
  // Python: zlib.crc32(b"123456789") = 0xcbf43926 (3421780262)
  @json.inspect(crc, content=3421780262)
}

///|
/// Test CRC-32 of "The quick brown fox jumps over the lazy dog" (Python verified)
test "crc32_quick_fox_python_verified" {
  let data = b"The quick brown fox jumps over the lazy dog"
  let crc = @crc32.bytes_crc32(data[:])
  // Python: zlib.crc32(b"The quick brown fox jumps over the lazy dog") = 0x414fa339 (1095738169)
  @json.inspect(crc, content=1095738169)
}

///|
/// Test CRC-32 of binary data with all byte values 0-15 (Python verified)
test "crc32_binary_data_python_verified" {
  let data = b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f"
  let crc = @crc32.bytes_crc32(data[:])
  // Python: zlib.crc32(bytes([0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15])) = 0xcecee288 (3469664904)
  @json.inspect(crc, content=3469664904)
}

///|
/// Test incremental CRC-32 computation with "hello world" (Python verified)
test "crc32_incremental_hello_world_python_verified" {
  let data = b"hello world"

  // Compute incrementally: "hello" + " world"
  let crc_incremental = @crc32.Crc32::init()
    .update_bytes(data[0:5]) // "hello"
    .update_bytes(data[5:11]) // " world"
    .finish()

  // Compute all at once
  let crc_direct = @crc32.bytes_crc32(data[:])

  // Both should match Python's result: 0x0d4a1185 (222957957)
  @json.inspect((crc_incremental, crc_direct, crc_incremental == crc_direct), content=[
    222957957, 222957957, true,
  ])
}

///|
/// Test incremental CRC-32 computation with "abc" (Python verified)
test "crc32_incremental_abc_python_verified" {
  let data = b"abc"

  // Compute incrementally: "a" + "bc"
  let crc_incremental = @crc32.Crc32::init()
    .update_bytes(data[0:1]) // "a"
    .update_bytes(data[1:3]) // "bc"
    .finish()

  // Compute all at once
  let crc_direct = @crc32.bytes_crc32(data[:])

  // Both should match Python's result: 0x352441c2 (891568578)
  @json.inspect((crc_incremental, crc_direct, crc_incremental == crc_direct), content=[
    891568578, 891568578, true,
  ])
}

///|
/// Test byte-by-byte CRC-32 computation (Python verified)
test "crc32_byte_by_byte_python_verified" {
  // Compute byte by byte
  let mut crc = @crc32.Crc32::init()
  crc = crc.update_byte('a'.to_int())
  crc = crc.update_byte('b'.to_int())
  crc = crc.update_byte('c'.to_int())
  let result = crc.finish()

  // Should match Python's result: 0x352441c2 (891568578)
  @json.inspect(result, content=891568578)
}

///|
/// Test CRC-32 partial data computation (Python verified)
test "crc32_partial_data_python_verified" {
  let data = b"hello world"

  // Test "hello" part (first 5 bytes)
  let crc_hello = @crc32.bytes_crc32(data[0:5])
  // Python: zlib.crc32(b"hello") = 0x3610a686 (907060870)

  // Test "world" part (last 5 bytes, skipping space)
  let crc_world = @crc32.bytes_crc32(data[6:11])
  // Python: zlib.crc32(b"world") = 0x3a771143 (980881731)

  @json.inspect((crc_hello, crc_world), content=[907060870, 980881731])
}

///|
/// Test CRC-32 state initialization and finalization (Python verified)
test "crc32_init_finish_python_verified" {
  // Empty computation should give 0
  let crc_empty = @crc32.Crc32::init().finish()
  @json.inspect(crc_empty, content=0)

  // Single byte 'A' (ASCII 65)
  let crc_a = @crc32.Crc32::init()
    .update_byte(65) // 'A'
    .finish()
  // Python: zlib.crc32(b"A") = 0xd3d99e8b (3554254475)
  @json.inspect(crc_a, content=3554254475)
}

///|
/// Test CRC-32 with large repeated data (Python verified)
test "crc32_large_repeated_python_verified" {
  // Test incremental computation of 100 'A' characters
  let mut crc = @crc32.Crc32::init()
  for i = 0; i < 100; i = i + 1 {
    crc = crc.update_byte('A'.to_int())
  }
  let result = crc.finish()

  // Python: zlib.crc32(b"A" * 100) = 0x9597bc8d (2509749389)
  @json.inspect(result, content=2509749389)
}

///|
/// Test CRC-32 edge cases: start and length parameters
test "crc32_edge_cases_python_verified" {
  let data = b"hello world"

  // Test different substrings
  let crc_hell = @crc32.bytes_crc32(data[0:4]) // "hell"
  let crc_ello = @crc32.bytes_crc32(data[1:5]) // "ello"
  let crc_space_world = @crc32.bytes_crc32(data[5:11]) // " world"

  // Python verification:
  // zlib.crc32(b"hell") = 0x1c8600e3 (478544099)
  // zlib.crc32(b"ello") = 0x7834b20b (2016719371)
  // zlib.crc32(b" world") = 0x4a3b42cb (1245397707)

  @json.inspect((crc_hell, crc_ello, crc_space_world), content=[
    478544099, 2016719371, 1245397707,
  ])
}
