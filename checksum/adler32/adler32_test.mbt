// Tests for Adler-32 checksum implementation

///|
/// Test Adler-32 of empty data
test "adler32_empty" {
  let adler = bytes_adler32(b"", 0, 0)
  @json.inspect((adler, adler == 1L), content=["1", true])
}

///|
/// Test Adler-32 of simple string
test "adler32_simple" {
  let data = b"hello world"
  let adler = bytes_adler32(data, 0, data.length())
  // Adler-32 of "hello world" should be 0x26e4023c (651924540 in decimal)
  @json.inspect(adler, content="436929629")
}

///|
/// Test incremental Adler-32 computation
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
/// Test Adler-32 with partial data
test "adler32_partial" {
  let data = b"hello world"
  let adler_hello = bytes_adler32(data, 0, 5)  // Just "hello"
  let adler_world = bytes_adler32(data, 6, 5)  // Just "world"
  // These should be different
  @json.inspect(adler_hello != adler_world, content=true)
}

///|
/// Test Adler-32 with single byte
test "adler32_single_byte" {
  let data = b"x"
  let adler = bytes_adler32(data, 0, 1)
  // Adler-32 starts at 1, adding 'x' (120): s1 = 121, s2 = 121
  // result = (121 << 16) | 121 = 7929977
  @json.inspect(adler, content="7929977")
}

///|
/// Test check_adler32 function
test "adler32_check" {
  let result_success = check_adler32(0x12345678L, 0x12345678L)
  let result_failure = check_adler32(0x12345678L, 0x87654321L)
  
  let success_ok = match result_success {
    Ok(_) => true
    Err(_) => false
  }
  
  let failure_err = match result_failure {
    Ok(_) => false
    Err(msg) => msg.contains("mismatch")
  }
  
  @json.inspect((success_ok, failure_err), content=[true, true])
}
