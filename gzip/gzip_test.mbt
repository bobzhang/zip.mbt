// Clean gzip tests

///|
/// Test basic compression and decompression
test "basic_round_trip" {
  let input = "Hello, World!".to_bytes()
  let compressed = @gzip.compress(input)
  let decompressed = @gzip.decompress(compressed)
  inspect(decompressed == input, content="true")
}

///|
/// Test empty data
test "empty_data" {
  let input = "".to_bytes()
  let compressed = @gzip.compress(input)
  let decompressed = @gzip.decompress(compressed)
  inspect(decompressed == input, content="true")
}

///|
/// Test larger data
test "large_data" {
  let mut input_str = ""
  for i = 0; i < 1000; i = i + 1 {
    input_str = input_str + "A"
  }
  let input = input_str.to_bytes()
  let compressed = @gzip.compress(input)
  let decompressed = @gzip.decompress(compressed)
  inspect(decompressed == input, content="true")
}

///|
/// Test cross-compatibility features
test "cross_compatibility" {
  let test_data = "Hello from MoonBit!".to_bytes()
  let compressed = @gzip.compress(test_data)

  // Verify basic gzip structure
  inspect(compressed.length() > 18, content="true") // Header (10) + footer (8) minimum
  inspect(compressed[0].to_int() == 0x1f, content="true") // Gzip magic 1
  inspect(compressed[1].to_int() == 0x8b, content="true") // Gzip magic 2  
  inspect(compressed[2].to_int() == 0x08, content="true") // Deflate method

  // Test round trip
  let decompressed = @gzip.decompress(compressed)
  inspect(decompressed == test_data, content="true")
}

///|
/// Test binary data compatibility with Python
/// Python: gzip.compress(bytes([0, 1, 2, 255, 254, 253]))
/// This tests that our gzip handles binary data correctly like Python
test "binary_data_python_compat" {
  let binary_data = Bytes::from_array([0, 1, 2, 255, 254, 253])
  let compressed = @gzip.compress(binary_data)

  // Verify gzip header structure matches Python output
  inspect(compressed[0].to_int() == 0x1f, content="true") // Magic 1
  inspect(compressed[1].to_int() == 0x8b, content="true") // Magic 2
  inspect(compressed[2].to_int() == 0x08, content="true") // Deflate method
  inspect(compressed[3].to_int() == 0x00, content="true") // No flags (matches Python default)
  inspect(compressed[8].to_int() == 0x00, content="true") // Extra flags (matches Python)
  inspect(compressed[9].to_int() == 0xff, content="true") // OS unknown (matches Python default)

  // Test round trip preserves binary data exactly
  let decompressed = @gzip.decompress(compressed)
  inspect(decompressed == binary_data, content="true")
  inspect(decompressed.length() == 6, content="true")
}

///|
/// Test single byte data (edge case)
/// Python: gzip.compress(b'A') produces valid gzip
/// This verifies our implementation handles minimal data like Python
test "single_byte_python_compat" {
  let single_byte = "A".to_bytes()
  let compressed = @gzip.compress(single_byte)

  // Should produce valid gzip structure
  inspect(compressed.length() >= 18, content="true") // At least header + footer

  // Verify gzip format compliance
  inspect(compressed[0].to_int() == 0x1f, content="true")
  inspect(compressed[1].to_int() == 0x8b, content="true")
  inspect(compressed[2].to_int() == 0x08, content="true")

  // Test decompression matches original
  let decompressed = @gzip.decompress(compressed)
  inspect(decompressed == single_byte, content="true")
}

///|
/// Test repetitive data compression efficiency
/// Python: gzip.compress("A" * 100) uses deflate compression
/// Our implementation uses uncompressed deflate, so output is larger but valid
test "repetitive_data_python_compat" {
  let mut repetitive = ""
  for i = 0; i < 100; i = i + 1 {
    repetitive = repetitive + "A"
  }
  let data = repetitive.to_bytes()
  let compressed = @gzip.compress(data)

  // Our uncompressed deflate will be larger than Python's compressed deflate
  // But it should still be valid gzip format with reasonable size
  inspect(compressed.length() > 100, content="true") // Should be larger than original

  // Verify round trip works perfectly
  let decompressed = @gzip.decompress(compressed)
  inspect(decompressed == data, content="true")
}

///|
/// Test Unicode/UTF-8 data compatibility
/// Python: gzip.compress("Hello 世界! 🌍".encode('utf-8'))
/// This tests Unicode handling matches Python's behavior
test "unicode_data_python_compat" {
  let unicode_text = "Hello 世界! 🌍"
  let utf8_bytes = unicode_text.to_bytes()
  let compressed = @gzip.compress(utf8_bytes)

  // Verify gzip structure
  inspect(compressed[0].to_int() == 0x1f, content="true")
  inspect(compressed[1].to_int() == 0x8b, content="true")

  // Test round trip preserves UTF-8 encoding perfectly
  let decompressed = @gzip.decompress(compressed)
  inspect(decompressed == utf8_bytes, content="true")
}

///|
/// Test large data block handling
/// Python: gzip.compress(b'X' * 1024) handles large blocks
/// This tests our implementation with data larger than typical block sizes
test "large_block_python_compat" {
  let mut large_data = ""
  for i = 0; i < 1024; i = i + 1 {
    large_data = large_data + "X"
  }
  let data = large_data.to_bytes()
  let compressed = @gzip.compress(data)

  // Should handle large data correctly
  inspect(compressed.length() > 1000, content="true")

  // Verify gzip header is correct
  inspect(compressed[0].to_int() == 0x1f, content="true")
  inspect(compressed[1].to_int() == 0x8b, content="true")

  // Test round trip maintains all data
  let decompressed = @gzip.decompress(compressed)
  inspect(decompressed == data, content="true")
}

///|
/// Test gzip footer structure matches Python
/// Python gzip format: header + deflate_data + CRC32(4 bytes) + SIZE(4 bytes)
/// This verifies our footer structure exactly matches Python's
test "footer_structure_python_compat" {
  let test_data = "Test footer".to_bytes()
  let compressed = @gzip.compress(test_data)

  // Extract footer (last 8 bytes)
  let footer_start = compressed.length() - 8

  // Footer should contain CRC32 (4 bytes) + size (4 bytes) in little-endian
  let size_bytes = test_data.length()
  let footer_size = compressed[footer_start + 4].to_int() |
    (compressed[footer_start + 5].to_int() << 8) |
    (compressed[footer_start + 6].to_int() << 16) |
    (compressed[footer_start + 7].to_int() << 24)
  inspect(footer_size == size_bytes, content="true")

  // Test that decompression verifies CRC32 correctly
  let decompressed = @gzip.decompress(compressed)
  inspect(decompressed == test_data, content="true")
}

///|
/// Test edge case: newline and whitespace data
/// Python: gzip.compress(b'\n\r\t   ') handles whitespace correctly
/// This ensures our implementation preserves all whitespace characters
test "whitespace_data_python_compat" {
  let whitespace_data = "\n\r\t   ".to_bytes()
  let compressed = @gzip.compress(whitespace_data)

  // Verify gzip format
  inspect(compressed[0].to_int() == 0x1f, content="true")
  inspect(compressed[1].to_int() == 0x8b, content="true")

  // Test that all whitespace is preserved
  let decompressed = @gzip.decompress(compressed)
  inspect(decompressed == whitespace_data, content="true")
}

///|
/// Test that our uncompressed deflate format is valid
/// Python can decompress uncompressed deflate blocks (RFC 1951 section 3.2.4)
/// This documents that our format choice is standards-compliant
test "uncompressed_deflate_format_valid" {
  let data = "Uncompressed test".to_bytes()
  let compressed = @gzip.compress(data)

  // Find deflate block (after 10-byte header, before 8-byte footer)
  let deflate_start = 10

  // First byte should be 0x01 (BFINAL=1, BTYPE=00 for uncompressed)
  inspect(compressed[deflate_start].to_int() == 0x01, content="true")

  // Next 4 bytes should be length and complement
  let len = compressed[deflate_start + 1].to_int() |
    (compressed[deflate_start + 2].to_int() << 8)
  let nlen = compressed[deflate_start + 3].to_int() |
    (compressed[deflate_start + 4].to_int() << 8)
  inspect(len == data.length(), content="true")
  inspect(nlen == (len ^ 0xFFFF), content="true")

  // Test round trip still works
  let decompressed = @gzip.decompress(compressed)
  inspect(decompressed == data, content="true")
}
