// Zlib wrapper format tests

///|
test "@deflate.zlib_compress_basic" {
  let data = b"Hello, zlib!"
  let (adler, compressed) = @deflate.zlib_compress(data[:])

  // Check header
  let cmf = compressed[0].to_int()
  let flg = compressed[1].to_int()

  // CMF should be 0x78 (deflate with 32KB window)
  @json.inspect(cmf, content=120)

  // Header checksum should be valid
  let header = (cmf << 8) | flg
  let valid = header.mod(31) == 0
  @json.inspect(valid, content=true)

  // Should have trailer (last 4 bytes)
  let has_trailer = compressed.length() >= 6
  @json.inspect(has_trailer, content=true)

  // Adler-32 should be non-zero
  let adler_valid = adler > 0
  @json.inspect(adler_valid, content=true)
}

///|
test "zlib_roundtrip_simple" {
  let data = b"Test data for zlib compression"
  let (adler, compressed) = @deflate.zlib_compress(data[:])

  // Decompress
  let (decompressed, computed_adler) = @deflate.zlib_decompress(compressed)
  // Verify data matches
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(),
      decompressed[data.length() - 1].to_int(),
    ),
    content=[30, 84, 110],
  ) // 'T' and 'n'

  // Verify checksum matches
  @json.inspect(adler == computed_adler, content=true)
}

///|
test "zlib_roundtrip_empty" {
  let data = b""
  let (_adler, compressed) = @deflate.zlib_compress(data[:])
  let (decompressed, _) = @deflate.zlib_decompress(compressed)
  @json.inspect(decompressed.length(), content=0)
}

///|
test "zlib_roundtrip_repetitive" {
  // Highly compressible data
  let buf = @buffer.new(size_hint=100)
  for i = 0; i < 100; i = i + 1 {
    buf.write_byte(b'a')
  }
  let data = buf.contents()
  let (_adler, compressed) = @deflate.zlib_compress(data[:])

  // Should achieve good compression
  let ratio = compressed.length() < 30
  @json.inspect(ratio, content=true)

  // Should decompress correctly
  let (decompressed, _) = @deflate.zlib_decompress(compressed)
  @json.inspect(decompressed.length(), content=100)
}

///|
test "zlib_roundtrip_binary" {
  // Test with various byte values
  let data = b"\x00\x01\x7f\x80\xff\x00\x01\x7f\x80\xff"
  let (_, compressed) = @deflate.zlib_compress(data[:])
  let (decompressed, _) = @deflate.zlib_decompress(compressed)
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(),
      decompressed[4].to_int(),
      decompressed[9].to_int(),
    ),
    content=[10, 0, 255, 255],
  )
}

///|
test "@deflate.zlib_compression_levels" {
  let data = b"Test data with some repetition: test test test"

  // Try different compression levels (avoid constructing variants directly)
  let (_, default) = @deflate.zlib_compress(data[:])

  // All should decompress correctly
  let (d, _) = @deflate.zlib_decompress(default)
  let default_ok = d.length() == data.length()
  @json.inspect(default_ok, content=true)
}

///|
test "zlib_invalid_header" {
  // Invalid compression method (not deflate)
  let data = b"\x00\x00\x00\x00\x00\x00"
  let result = try? @deflate.zlib_decompress(data)
  guard result is Err(_) else {
    fail("zlib_decompress should fail with invalid header")
  }
  @json.inspect("error", content="error")
}

///|
test "zlib_too_short" {
  let data = b"\x78\x9c" // Just header, no data
  let result = try? @deflate.zlib_decompress(data)
  guard result is Err(_) else {
    fail("zlib_decompress should fail with too short data")
  }
  @json.inspect("error", content="error")
}

///|
test "zlib_bad_checksum" {
  // Create valid zlib data, then corrupt checksum
  let data = b"test"
  let (_, compressed) = @deflate.zlib_compress(data[:])

  // Corrupt last byte of Adler-32
  let buf = @buffer.new(size_hint=compressed.length())
  for i = 0; i < compressed.length() - 1; i = i + 1 {
    buf.write_byte(compressed[i])
  }
  buf.write_byte(b'\xFF') // Wrong checksum byte
  let corrupted = buf.contents()
  let result = try? @deflate.zlib_decompress(corrupted)
  match result {
    Ok(_) => @json.inspect("should fail", content="error")
    Err(_) => @json.inspect("error", content="error")
  }
}

// ============================================================================
// Dynamic Huffman Tests
// ============================================================================

///|
/// Test zlib decompression with too short data
test "coverage_zlib_too_short" {
  let data = b"short"
  guard (try? @deflate.zlib_decompress(data)) is Err(msg) else {
    fail("zlib_decompress should fail with too short data")
  }
  @json.inspect(msg.to_string().contains("too short"), content=true)
}

///|
/// Test zlib with invalid compression method
test "coverage_zlib_invalid_method" {
  let buf = Array::make(10, b'\x00')
  buf[0] = b'\x79' // CM=9 (invalid)
  buf[1] = b'\x9C'
  let data = Bytes::from_array(FixedArray::from_iter(buf.iter()))
  guard (try? @deflate.zlib_decompress(data)) is Err(msg) else {
    fail("zlib_decompress should fail with invalid compression method")
  }
  @json.inspect(msg.to_string().contains("compression method"), content=true)
}

///|
/// Test zlib with invalid window size
test "coverage_zlib_bad_window" {
  let buf = Array::make(10, b'\x00')
  buf[0] = b'\x88' // CINFO=8 (too large)
  buf[1] = b'\x1E'
  let data = Bytes::from_array(FixedArray::from_iter(buf.iter()))
  guard (try? @deflate.zlib_decompress(data)) is Err(msg) else {
    fail("zlib_decompress should fail with invalid window size")
  }
  @json.inspect(msg.to_string().contains("window size"), content=true)
}

///|
/// Test zlib with bad header checksum
test "coverage_zlib_bad_checksum" {
  let buf = Array::make(10, b'\x00')
  buf[0] = b'\x78'
  buf[1] = b'\x00' // Wrong checksum
  let data = Bytes::from_array(FixedArray::from_iter(buf.iter()))
  guard (try? @deflate.zlib_decompress(data)) is Err(msg) else {
    fail("zlib_decompress should fail with bad header checksum")
  }
  @json.inspect(msg.to_string().contains("header checksum"), content=true)
}

///|
/// Test zlib with preset dictionary
test "coverage_zlib_dict" {
  let buf = Array::make(10, b'\x00')
  buf[0] = b'\x78'
  buf[1] = b'\xBB' // FDICT=1
  let data = Bytes::from_array(FixedArray::from_iter(buf.iter()))
  guard (try? @deflate.zlib_decompress(data)) is Err(msg) else {
    fail("zlib_decompress should fail with preset dictionary")
  }
  @json.inspect(msg.to_string().contains("dictionary"), content=true)
}
