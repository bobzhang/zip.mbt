// Deflate compression tests

///|
/// Inflate tests - uncompressed block
test "inflate_uncompressed_block" {
  // Create a simple uncompressed deflate stream
  // Format: final_bit(1) + type(00) + padding + length + ~length + data
  // Data: "ABC" (3 bytes)
  let compressed = Bytes::from_array([
    0b00000001, // final=1, type=00 (uncompressed)
     3, 0, // length = 3 (little-endian)
     252, 255, // ~length = 0xFFFC (complement of 3)
     0x41, 0x42, 0x43, // "ABC"
  ])
  let result = @deflate.inflate(compressed)
  @json.inspect((result[0].to_int(), result[1].to_int(), result[2].to_int()), content=[
    65, 66, 67,
  ])
}

///|
/// Deflate compression tests
test "file_deflate_of_bytes_basic" {
  let data = b"Hello, World!"
  let file = @file.File::deflate_of_bytes(data, 0, data.length())
  @json.inspect(file.compression is Deflate, content=true)
  @json.inspect(file.decompressed_size, content=13)
  // With LZ77+Huffman, compressed size will be smaller than stored format
  // Just verify it's reasonable (not larger than original + overhead)
  let reasonable = file.compressed_size > 0 && file.compressed_size < 30
  @json.inspect(reasonable, content=true)
}

///|
test "file_deflate_roundtrip" {
  // Test that deflate compression creates data that can be decompressed
  let original = b"Test data for deflate roundtrip!"
  let file = @file.File::deflate_of_bytes(original, 0, original.length())
  // Decompress and verify
  let decompressed = file.to_bytes()
  @json.inspect(
    (
      decompressed.length() == original.length(),
      decompressed[0] == original[0],
      decompressed[original.length() - 1] == original[original.length() - 1],
    ),
    content=[true, true, true],
  )
}

///|
test "file_deflate_empty_data" {
  let data = b""
  let file = @file.File::deflate_of_bytes(data, 0, 0)
  @json.inspect(file.decompressed_size, content=0)
  // Empty deflate with LZ77+Huffman: block header + EOB symbol
  // Should be very small (< 5 bytes)
  let small = file.compressed_size > 0 && file.compressed_size < 5
  @json.inspect(small, content=true)
}

///|
test "archive_roundtrip_deflate" {
  let data = b"Test deflate compression in ZIP"
  let file = @file.File::deflate_of_bytes(data, 0, data.length())
  let m = @member.make("compressed.txt", File(file))
  let original = @zip.Archive::empty()
  original.add(m)

  // Encode
  let bytes = original.to_bytes()

  // Decode and decompress
  let decoded = @zip.Archive::of_bytes(bytes)
  guard decoded.find("compressed.txt") is Some(found) else {
    fail("should find compressed.txt")
  }
  guard found.kind() is File(f) else { fail("compressed.txt should be a file") }
  let extracted = f.to_bytes()
  @json.inspect((extracted.length(), extracted[0] == data[0]), content=[
    31, true,
  ])
}

///|
// ============================================================================
// LZ77 String Matching Tests
// ============================================================================

// ============================================================================
// Full LZ77 + Huffman Compression Tests
// ============================================================================

///|
test "deflate_fixed_empty" {
  let data = b""
  let compressed = @deflate.deflate_fixed(data[0:0], true, 4, 4096)
  let decompressed = @deflate.inflate(compressed, decompressed_size=0)
  @json.inspect(decompressed.length(), content=0)
}

///|
test "deflate_fixed_simple" {
  let data = b"hello"
  let compressed = @deflate.deflate_fixed(data, true, 4, 4096)
  let decompressed = @deflate.inflate(
    compressed,
    decompressed_size=data.length(),
  )
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(),
      decompressed[1].to_int(),
      decompressed[2].to_int(),
      decompressed[3].to_int(),
      decompressed[4].to_int(),
    ),
    content=[5, 104, 101, 108, 108, 111],
  )
}

///|
test "deflate_fixed_with_repetition" {
  // String with obvious repetition that LZ77 should compress
  let data = b"abcabcabcabc"
  let compressed = @deflate.deflate_fixed(data, true, 4, 4096)
  let decompressed = @deflate.inflate(
    compressed,
    decompressed_size=data.length(),
  )

  // Should decompress correctly
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(), // 'a'
      decompressed[3].to_int(), // 'a'
      decompressed[6].to_int(), // 'a'
      decompressed[9].to_int(), // 'a'
    ),
    content=[12, 97, 97, 97, 97],
  )

  // Compressed should be smaller than original due to LZ77
  let is_smaller = compressed.length() < data.length()
  @json.inspect(is_smaller, content=true)
}

///|
test "deflate_fixed_longer_text" {
  let data = b"The quick brown fox jumps over the lazy dog. The quick brown fox."
  let compressed = @deflate.deflate_fixed(data, true, 4, 4096)
  let decompressed = @deflate.inflate(
    compressed,
    decompressed_size=data.length(),
  )

  // Verify length and some key characters
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(), // 'T'
      decompressed[46].to_int(), // 'h' (in "The" second time)
      decompressed[decompressed.length() - 1].to_int(), // '.'
    ),
    content=[65, 84, 104, 46],
  )
}

///|
test "deflate_fixed_all_same" {
  // Highly compressible: all same byte
  let buf = @buffer.new(size_hint=100)
  for i = 0; i < 100; i = i + 1 {
    buf.write_byte(b'a')
  }
  let data = buf.contents()
  let compressed = @deflate.deflate_fixed(data, true, 4, 4096)
  let decompressed = @deflate.inflate(
    compressed,
    decompressed_size=data.length(),
  )

  // Should decompress to correct length
  @json.inspect(decompressed.length(), content=100)

  // Should be highly compressed (much smaller)
  let ratio = compressed.length() < 20
  @json.inspect(ratio, content=true)
}

///|
test "deflate_fixed_binary_data" {
  // Test with various byte values including null bytes
  let data = b"\x00\x01\x02\x03\x00\x01\x02\x03\xff\xfe\xfd"
  let compressed = @deflate.deflate_fixed(data, true, 4, 4096)
  let decompressed = @deflate.inflate(
    compressed,
    decompressed_size=data.length(),
  )
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(),
      decompressed[4].to_int(), // Should match [0] due to repetition
      decompressed[10].to_int(),
    ),
    content=[11, 0, 0, 253],
  )
}

///|
test "deflate_fixed_no_compression_benefit" {
  // Random-looking data that won't compress well
  let data = b"abcdefghijklmnop"
  let compressed = @deflate.deflate_fixed(data, true, 4, 4096)
  let decompressed = @deflate.inflate(
    compressed,
    decompressed_size=data.length(),
  )

  // Should still decompress correctly even if not smaller
  @json.inspect(
    (decompressed.length(), decompressed[0].to_int(), decompressed[15].to_int()),
    content=[16, 97, 112],
  )
}

///|
test "deflate_fixed_substring_matches" {
  // Test lazy matching with overlapping potential matches
  let data = b"aaabbbaaabbbccc"
  let compressed = @deflate.deflate_fixed(data, true, 4, 4096)
  let decompressed = @deflate.inflate(
    compressed,
    decompressed_size=data.length(),
  )
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(), // 'a'
      decompressed[6].to_int(), // 'a' (second occurrence)
      decompressed[12].to_int(), // 'c'
    ),
    content=[15, 97, 97, 99],
  )
}

// ============================================================================
// End-to-End Integration Tests
// ============================================================================

///|
test "complete_zip_workflow_with_compression" {
  // Demonstrate complete ZIP workflow with real compression

  // 1. Create multiple files with different characteristics
  let text1 = b"The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog."
  let text2 = b"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" // Highly compressible
  let text3 = b"Random data: x7f3k9m2p"

  // 2. Compress files
  let file1 = @file.File::deflate_of_bytes(text1, 0, text1.length())
  let file2 = @file.File::deflate_of_bytes(text2, 0, text2.length())
  let file3 = @file.File::deflate_of_bytes(text3, 0, text3.length())

  // 3. Create members
  let m1 = @member.make("doc.txt", File(file1))
  let m2 = @member.make("repeated.txt", File(file2))
  let m3 = @member.make("random.txt", File(file3))

  // 4. Build archive
  let archive = @zip.Archive::empty()
  archive.add(m1)
  archive.add(m2)
  archive.add(m3)

  // 5. Serialize to ZIP format
  let zip_bytes = archive.to_bytes()

  // 6. Verify it's a valid ZIP (deserialize)
  let decoded = @zip.Archive::of_bytes(zip_bytes)

  // 7. Extract and verify each file
  guard decoded.find("doc.txt") is Some(entry) else {
    fail("should find doc.txt")
  }
  guard entry.kind() is File(f) else { fail("doc.txt should be a file") }
  let data = f.to_bytes()
  @json.inspect((data.length(), data[0].to_int()), content=[89, 84]) // 'T'
  guard decoded.find("repeated.txt") is Some(entry) else {
    fail("should find repeated.txt")
  }
  guard entry.kind() is File(f) else { fail("repeated.txt should be a file") }
  let data = f.to_bytes()
  // Verify it decompressed correctly
  @json.inspect((data.length(), data[0].to_int(), data[39].to_int()), content=[
    40, 97, 97,
  ])

  // Verify actual compression happened
  let ratio = f.compressed_size() < 15 // Should be < 40% of original
  @json.inspect(ratio, content=true)
  guard decoded.find("random.txt") is Some(entry) else {
    fail("should find random.txt")
  }
  guard entry.kind() is File(f) else { fail("random.txt should be a file") }
  let data = f.to_bytes()
  @json.inspect(data.length(), content=22)

  // 8. Verify archive has all members
  let count = decoded.fold(fn(_m, acc) { acc + 1 }, 0)
  @json.inspect(count, content=3)
}

// ============================================================================
// zlib Wrapper Format Tests (RFC 1950)
// ============================================================================

///|
test "dynamic_huffman_simple" {
  // Create ASCII bytes directly (not from UTF-16 string)
  let data = b"AAAAAABBBBBBCCCCCC"
  let compressed = @deflate.deflate_dynamic(data, true, 8, 128)

  // Should decompress correctly
  let decompressed = @deflate.inflate(compressed)
  @json.inspect(decompressed, content="AAAAAABBBBBBCCCCCC")
}

///|
test "dynamic_huffman_vs_fixed" {
  // Data with non-uniform distribution - test both compress correctly
  let data = b"AAAAAAAAAAABBBBBCCCCCDDD"
  let dynamic = @deflate.deflate_dynamic(data, true, 8, 128)
  let fixed = @deflate.deflate_fixed(data, true, 8, 128)

  // Both should decompress correctly
  let d1 = @deflate.inflate(dynamic)
  let d2 = @deflate.inflate(fixed)
  @json.inspect((d1, d2), content=[
    "AAAAAAAAAAABBBBBCCCCCDDD", "AAAAAAAAAAABBBBBCCCCCDDD",
  ])

  // Note: For short data, dynamic may be larger due to header overhead
  // Dynamic Huffman is beneficial for larger blocks (typically >1KB)
}

///|
test "dynamic_huffman_single_symbol" {
  // All same character - should compress well with LZ77
  let data = b"AAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  let compressed = @deflate.deflate_dynamic(data, true, 8, 128)

  // Should compress to less than original (LZ77 + dynamic Huffman)
  let decompressed = @deflate.inflate(compressed)
  @json.inspect((compressed.length() < data.length(), decompressed.length()), content=[
    true, 28,
  ])
}

///|
test "dynamic_huffman_empty" {
  let compressed = @deflate.deflate_dynamic([], true, 8, 128)
  let decompressed = @deflate.inflate(compressed)
  @json.inspect(decompressed.length(), content=0)
}

///|
test "dynamic_huffman_short" {
  let data = b"Hi"
  let compressed = @deflate.deflate_dynamic(data, true, 8, 128)
  let decompressed = @deflate.inflate(compressed)
  @json.inspect(decompressed, content="Hi")
}

///|
test "dynamic_huffman_text" {
  let data = b"The quick brown fox jumps over the lazy dog."
  let compressed = @deflate.deflate_dynamic(data, true, 8, 128)

  // Should compress well
  let decompressed = @deflate.inflate(compressed)
  @json.inspect(
    decompressed,
    content="The quick brown fox jumps over the lazy dog.",
  )
}

///|
test "dynamic_huffman_binary" {
  // Binary data with all byte values
  let data = Array::make(256, b'\x00')
  for i = 0; i < 256; i = i + 1 {
    data[i] = i.to_byte()
  }
  let data_bytes = Bytes::from_array(FixedArray::from_iter(data[0:].iter()))
  let compressed = @deflate.deflate_dynamic(data_bytes[0:256], true, 8, 128)
  let decompressed = @deflate.inflate(compressed)
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(),
      decompressed[255].to_int(),
    ),
    content=[256, 0, 255],
  )
}

///|
test "dynamic_vs_fixed" {
  // Compare compression ratios
  let data = b"AAAA"
  let dynamic = @deflate.deflate_dynamic(data, true, 8, 128)
  let fixed = @deflate.deflate_fixed(data, true, 8, 128)

  // Both must decompress correctly
  let d1 = @deflate.inflate(dynamic)
  let d2 = @deflate.inflate(fixed)
  @json.inspect((d1, d2), content=["AAAA", "AAAA"])
}

// ============================================================================
// Integration Tests - Verify compression level selection
// ============================================================================

///|
test "compression_level_fast_integration" {
  // Fast level should compress and decompress correctly
  let data = b"AAAABBBBCCCCDDDDEEEEFFFFGGGG" // 28 bytes
  let file = @file.File::deflate_of_bytes(data, 0, data.length())
  // Decompress and verify
  let decompressed = @deflate.inflate(
    file.compressed_bytes[file.start:file.start + file.compressed_size],
  )
  @json.inspect(decompressed, content="AAAABBBBCCCCDDDDEEEEFFFFGGGG")
}

///|
test "compression_level_large_data_integration" {
  // Large data should use dynamic Huffman for better compression
  let data = Array::make(300, b'A')
  for i = 0; i < 100; i = i + 1 {
    data[i] = b'A'
  }
  for i = 100; i < 200; i = i + 1 {
    data[i] = b'B'
  }
  for i = 200; i < 300; i = i + 1 {
    data[i] = b'C'
  }
  let data_bytes = Bytes::from_array(FixedArray::from_iter(data[0:].iter()))
  let file = @file.File::deflate_of_bytes(data_bytes, 0, 300)
  // Decompress and verify  
  let decompressed = @deflate.inflate(
    file.compressed_bytes[file.start:file.start + file.compressed_size],
  )
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(),
      decompressed[150].to_int(),
      decompressed[250].to_int(),
    ),
    content=[300, 65, 66, 67],
  )
}

///|
test "compression_with_lz77_matches" {
  // Repetitive data should compress well with LZ77 + Huffman
  let data = b"The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog."
  let file = @file.File::deflate_of_bytes(data, 0, data.length())
  // Should achieve good compression ratio
  @json.inspect(file.compressed_size < data.length(), content=true)
  // Verify decompression
  let decompressed = @deflate.inflate(
    file.compressed_bytes[file.start:file.start + file.compressed_size],
  )
  @json.inspect(decompressed.length() == data.length(), content=true)
}
// ============================================================================
// High-level DEFLATE API Compatibility Tests
// ============================================================================

///|
test "deflate_api_basic" {
  let data = b"Hello, DEFLATE API!"
  let compressed = @deflate.deflate(data)
  // Should compress successfully
  @json.inspect(compressed.length() > 0, content=true)

  // Should decompress back to original
  let decompressed = @deflate.inflate(
    compressed,
    decompressed_size=data.length(),
  )
  @json.inspect(decompressed.length(), content=19)
}

///|
/// Test file to_bytes_no_crc_check
test "coverage_no_crc_check" {
  let data = b"No CRC check"
  let file = @file.File::deflate_of_bytes(data, 0, data.length())
  let (dec, crc) = file.to_bytes_no_crc_check()
  @json.inspect((dec == data, crc == file.decompressed_crc32()), content=[
    true, true,
  ])
}

///|
/// Test large data triggering dynamic Huffman (>= 256 bytes)
test "coverage_large_data_dynamic" {
  let buf = Array::make(300, b'A')
  for i = 0; i < 300; i = i + 1 {
    buf[i] = (65 + i.mod(26)).to_byte()
  }
  let data = Bytes::from_array(FixedArray::from_iter(buf.iter()))
  let file = @file.File::deflate_of_bytes(data, 0, data.length())
  let dec = file.to_bytes()
  @json.inspect((dec.length(), dec == data), content=[300, true])
}
