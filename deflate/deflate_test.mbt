// Tests for deflate compression and decompression

test "inflate_uncompressed_block" {
  let compressed = Bytes::from_fixedarray([
    0b00000001, // final=1, type=00 (uncompressed)
     3, 0, // length = 3 (little-endian)
     252, 255, // ~length = 0xFFFC (complement of 3)
     0x41, 0x42, 0x43, // "ABC"
  ])
  let result = inflate(compressed, 0, compressed.length(), None)
  @json.inspect((result[0].to_int(), result[1].to_int(), result[2].to_int()), content=[
    65, 66, 67,
  ])
}

test "inflate_with_crc32" {
  let compressed = Bytes::from_fixedarray([
    0b00000001, 3, 0, 252, 255, 0x41, 0x42, 0x43,
  ])
  let (result, crc) = inflate_and_crc32(
    compressed,
    0,
    compressed.length(),
    None,
  )
  @json.inspect(
    (result[0].to_int(), result[1].to_int(), result[2].to_int(), crc > 0L),
    content=[65, 66, 67, true],
  )
}

test "inflate_with_adler32" {
  let compressed = Bytes::from_fixedarray([
    0b00000001, 3, 0, 252, 255, 0x41, 0x42, 0x43,
  ])
  let (result, adler) = inflate_and_adler32(
    compressed,
    0,
    compressed.length(),
    None,
  )
  @json.inspect(
    (result[0].to_int(), result[1].to_int(), result[2].to_int(), adler > 0L),
    content=[65, 66, 67, true],
  )
}

test "deflate_stored_basic" {
  let data = b"hello"
  let compressed = deflate_stored(data, 0, data.length())
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  @json.inspect(
    (decompressed.length(), decompressed[0].to_int()),
    content=[5, 104],
  ) // 'h'
}

test "deflate_fixed_literals_hello" {
  let data = b"hello"
  let compressed = deflate_fixed_literals_only(data, 0, data.length(), true)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  @json.inspect(
    (decompressed.length(), decompressed[0].to_int(), decompressed[4].to_int()),
    content=[5, 104, 111],
  ) // 'h' and 'o'
}

test "deflate_fixed_literals_empty" {
  let data = b""
  let compressed = deflate_fixed_literals_only(data, 0, 0, true)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(0))
  @json.inspect(decompressed.length(), content=0)
}

test "deflate_fixed_simple" {
  let data = b"hello"
  let compressed = deflate_fixed(data, 0, data.length(), true, 4, 4096)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  @json.inspect(
    (decompressed.length(), decompressed[0].to_int()),
    content=[5, 104],
  ) // 'h'
}

test "deflate_fixed_with_repetition" {
  let data = b"abcabcabcabc"
  let compressed = deflate_fixed(data, 0, data.length(), true, 4, 4096)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  @json.inspect(
    (decompressed.length(), decompressed[0].to_int(), compressed.length() < data.length()),
    content=[12, 97, true],
  ) // 'a' and should compress
}

test "deflate_fixed_all_same" {
  let buf = @buffer.ByteBuf::new(100, false)
  for i = 0; i < 100; i = i + 1 {
    buf.add_byte(0x61)
  }
  let data = buf.contents()
  
  let compressed = deflate_fixed(data, 0, data.length(), true, 4, 4096)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  @json.inspect(
    (decompressed.length(), compressed.length() < 20),
    content=[100, true],
  )
}

test "deflate_dynamic_simple" {
  let data = b"hello"
  let compressed = deflate_dynamic(data, 0, data.length(), true, 4, 4096)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  @json.inspect(
    (decompressed.length(), decompressed[0].to_int()),
    content=[5, 104],
  ) // 'h'
}

test "deflate_dynamic_with_repetition" {
  let data = b"abcabcabcabcabcabcabcabc"
  let compressed = deflate_dynamic(data, 0, data.length(), true, 8, 1024)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  @json.inspect(
    (decompressed.length(), decompressed[0].to_int(), compressed.length() < data.length()),
    content=[24, 97, true],
  ) // 'a' and should compress
}

test "deflate_dynamic_highly_compressible" {
  let buf = @buffer.ByteBuf::new(200, false)
  for i = 0; i < 200; i = i + 1 {
    buf.add_byte(0x61) // 'a'
  }
  let data = buf.contents()
  
  let compressed = deflate_dynamic(data, 0, data.length(), true, 8, 1024)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  @json.inspect(
    (decompressed.length(), compressed.length() < 30),
    content=[200, true],
  )
}

test "length_to_symbol_basic" {
  @json.inspect(
    (length_to_symbol(3), length_to_symbol(10), length_to_symbol(258)),
    content=[257, 264, 285],
  )
}

test "distance_to_symbol_basic" {
  @json.inspect(
    (distance_to_symbol(1), distance_to_symbol(4), distance_to_symbol(32768)),
    content=[0, 3, 29],
  )
}

test "build_optimal_code_lengths_single" {
  let freqs = Array::make(10, 0)
  freqs[5] = 100
  let lengths = build_optimal_code_lengths(freqs, 9, 15)
  @json.inspect(lengths[5], content=1)
}

test "build_optimal_code_lengths_two" {
  let freqs = Array::make(10, 0)
  freqs[3] = 50
  freqs[7] = 50
  let lengths = build_optimal_code_lengths(freqs, 9, 15)
  @json.inspect((lengths[3], lengths[7]), content=[1, 1])
}
