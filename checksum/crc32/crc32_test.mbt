// Tests for CRC-32 checksum implementation

///|
/// Test CRC-32 of empty data
test "crc32_empty" {
  let crc = bytes_crc32(b"", 0, 0)
  @json.inspect((crc, crc == 0), content=[0, true])
}

///|
/// Test CRC-32 of simple string
test "crc32_simple" {
  let data = b"hello world"
  let crc = bytes_crc32(data, 0, data.length())
  // CRC-32 of "hello world" should be 0x0d4a1185 (222957317 in decimal)
  @json.inspect(crc, content=222957957)
}

///|
/// Test incremental CRC-32 computation
test "crc32_incremental" {
  let data = b"hello world"
  let crc1 = Crc32::init()
    .update_bytes(data, 0, 5) // "hello"
    .update_bytes(data, 5, 6) // " world"
    .finish()
  let crc2 = @crc32.bytes_crc32(data, 0, data.length())
  @json.inspect((crc1 == crc2, crc1), content=[true, 222957957])
}

///|
/// Test CRC-32 check function with matching values
test "crc32_check_success" {
  let result = @crc32.check_crc32(0x12345678, 0x12345678)
  @json.inspect(result, content={ "Ok": null })
}

///|
/// Test CRC-32 check function with mismatched values
test "crc32_check_failure" {
  let result = @crc32.check_crc32(0x12345678, 0x87654321)
  match result {
    Ok(_) => @json.inspect("should not succeed", content="\"mismatch\"")
    Err(msg) => @json.inspect(msg.contains("mismatch"), content=true)
  }
}

///|
/// Test CRC-32 update_byte method
test "crc32_update_byte" {
  let mut crc = Crc32::init()
  crc = crc.update_byte('h'.to_int())
  crc = crc.update_byte('i'.to_int())
  let result = crc.finish()
  // Just verify it produces a non-zero result
  @json.inspect(result != 0, content=true)
}

///|
/// Test CRC-32 with partial data
test "crc32_partial" {
  let data = b"hello world"
  let crc_hello = bytes_crc32(data, 0, 5) // Just "hello"
  let crc_world = bytes_crc32(data, 6, 5) // Just "world"
  // These should be different
  @json.inspect(crc_hello != crc_world, content=true)
}
