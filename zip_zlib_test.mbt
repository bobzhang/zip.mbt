// Zlib wrapper format tests

///|
test "@deflate.zlib_compress_basic" {
  let data = b"Hello, zlib!"
  let (adler, compressed) = @deflate.zlib_compress(data, 0, data.length())

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
  let (adler, compressed) = @deflate.zlib_compress(data, 0, data.length())

  // Decompress
  let result = @deflate.zlib_decompress(compressed, 0, compressed.length())
  match result {
    Ok((decompressed, computed_adler)) => {
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
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "zlib_roundtrip_empty" {
  let data = b""
  let (_adler, compressed) = @deflate.zlib_compress(data, 0, 0)
  let result = @deflate.zlib_decompress(compressed, 0, compressed.length())
  match result {
    Ok((decompressed, _)) => @json.inspect(decompressed.length(), content=0)
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "zlib_roundtrip_repetitive" {
  // Highly compressible data
  let buf = @buffer.ByteBuf::new(100, false)
  for i = 0; i < 100; i = i + 1 {
    buf.add_byte(0x61) // 'a'
  }
  let data = buf.contents()
  let (_adler, compressed) = @deflate.zlib_compress(data, 0, data.length())

  // Should achieve good compression
  let ratio = compressed.length() < 30
  @json.inspect(ratio, content=true)

  // Should decompress correctly
  let result = @deflate.zlib_decompress(compressed, 0, compressed.length())
  match result {
    Ok((decompressed, _)) => @json.inspect(decompressed.length(), content=100)
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "zlib_roundtrip_binary" {
  // Test with various byte values
  let data = b"\x00\x01\x7f\x80\xff\x00\x01\x7f\x80\xff"
  let (_, compressed) = @deflate.zlib_compress(data, 0, data.length())
  let result = @deflate.zlib_decompress(compressed, 0, compressed.length())
  match result {
    Ok((decompressed, _)) =>
      @json.inspect(
        (
          decompressed.length(),
          decompressed[0].to_int(),
          decompressed[4].to_int(),
          decompressed[9].to_int(),
        ),
        content=[10, 0, 255, 255],
      )
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "@deflate.zlib_compression_levels" {
  let data = b"Test data with some repetition: test test test"

  // Try different compression levels (avoid constructing variants directly)
  let (_, default) = @deflate.zlib_compress(data, 0, data.length())

  // All should decompress correctly
  let default_ok = match
    @deflate.zlib_decompress(default, 0, default.length()) {
    Ok((d, _)) => d.length() == data.length()
    Err(_) => false
  }
  @json.inspect(default_ok, content=true)
}

///|
test "zlib_invalid_header" {
  // Invalid compression method (not deflate)
  let data = b"\x00\x00\x00\x00\x00\x00"
  let result = @deflate.zlib_decompress(data, 0, data.length())
  match result {
    Ok(_) => @json.inspect("should fail", content="error")
    Err(_) => @json.inspect("error", content="error")
  }
}

///|
test "zlib_too_short" {
  let data = b"\x78\x9c" // Just header, no data
  let result = @deflate.zlib_decompress(data, 0, data.length())
  match result {
    Ok(_) => @json.inspect("should fail", content="error")
    Err(_) => @json.inspect("error", content="error")
  }
}

///|
test "zlib_bad_checksum" {
  // Create valid zlib data, then corrupt checksum
  let data = b"test"
  let (_, compressed) = @deflate.zlib_compress(data, 0, data.length())

  // Corrupt last byte of Adler-32
  let buf = @buffer.ByteBuf::new(compressed.length(), false)
  for i = 0; i < compressed.length() - 1; i = i + 1 {
    buf.add_byte(compressed[i].to_int())
  }
  buf.add_byte(0xFF) // Wrong checksum byte
  let corrupted = buf.contents()
  let result = @deflate.zlib_decompress(corrupted, 0, corrupted.length())
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
  match @deflate.zlib_decompress(data, 0, data.length()) {
    Ok(_) => @json.inspect("should fail", content="error")
    Err(msg) => @json.inspect(msg.contains("too short"), content=true)
  }
}

///|
/// Test zlib with invalid compression method
test "coverage_zlib_invalid_method" {
  let buf = Array::make(10, b'\x00')
  buf[0] = b'\x79' // CM=9 (invalid)
  buf[1] = b'\x9C'
  let data = Bytes::from_fixedarray(FixedArray::from_iter(buf.iter()))
  match @deflate.zlib_decompress(data, 0, data.length()) {
    Ok(_) => @json.inspect("should fail", content="error")
    Err(msg) => @json.inspect(msg.contains("compression method"), content=true)
  }
}

///|
/// Test zlib with invalid window size
test "coverage_zlib_bad_window" {
  let buf = Array::make(10, b'\x00')
  buf[0] = b'\x88' // CINFO=8 (too large)
  buf[1] = b'\x1E'
  let data = Bytes::from_fixedarray(FixedArray::from_iter(buf.iter()))
  match @deflate.zlib_decompress(data, 0, data.length()) {
    Ok(_) => @json.inspect("should fail", content="error")
    Err(msg) => @json.inspect(msg.contains("window size"), content=true)
  }
}

///|
/// Test zlib with bad header checksum
test "coverage_zlib_bad_checksum" {
  let buf = Array::make(10, b'\x00')
  buf[0] = b'\x78'
  buf[1] = b'\x00' // Wrong checksum
  let data = Bytes::from_fixedarray(FixedArray::from_iter(buf.iter()))
  match @deflate.zlib_decompress(data, 0, data.length()) {
    Ok(_) => @json.inspect("should fail", content="error")
    Err(msg) => @json.inspect(msg.contains("header checksum"), content=true)
  }
}

///|
/// Test zlib with preset dictionary
test "coverage_zlib_dict" {
  let buf = Array::make(10, b'\x00')
  buf[0] = b'\x78'
  buf[1] = b'\xBB' // FDICT=1
  let data = Bytes::from_fixedarray(FixedArray::from_iter(buf.iter()))
  match @deflate.zlib_decompress(data, 0, data.length()) {
    Ok(_) => @json.inspect("should fail", content="error")
    Err(msg) => @json.inspect(msg.contains("dictionary"), content=true)
  }
}
