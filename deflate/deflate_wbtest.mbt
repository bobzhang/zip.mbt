// Whitebox tests for internal DEFLATE functions
// These test implementation details not exposed in the public API

///|
test "deflate_stored_basic" {
  let data = b"hello"
  let compressed = deflate_stored(data[:])
  let decompressed = inflate(compressed, decompressed_size=data.length())
  @json.inspect((decompressed.length(), decompressed[0].to_int()), content=[
    5, 104,
  ]) // 'h'
}

///|
// test "deflate_fixed_literals_hello" {
//   let data = b"hello"
//   let compressed = deflate_fixed_literals_only(data, 0, data.length(), true)
//   let decompressed = inflate(
//     compressed,
//     0,
//     compressed.length(),
//     Some(data.length()),
//   )
//   @json.inspect(
//     (decompressed.length(), decompressed[0].to_int(), decompressed[4].to_int()),
//     content=[5, 104, 111],
//   ) // 'h' and 'o'
// }

///|
// test "deflate_fixed_literals_empty" {
//   let data = b""
//   let compressed = deflate_fixed_literals_only(data, 0, 0, true)
//   let decompressed = inflate(compressed, 0, compressed.length(), Some(0))
//   @json.inspect(decompressed.length(), content=0)
// }

///|
test "deflate_fixed_simple" {
  let data = b"hello"
  let compressed = deflate_fixed(data, true, 4, 4096)
  let decompressed = inflate(compressed, decompressed_size=data.length())
  @json.inspect((decompressed.length(), decompressed[0].to_int()), content=[
    5, 104,
  ]) // 'h'
}

///|
test "deflate_fixed_with_repetition" {
  let data = b"abcabcabcabc"
  let compressed = deflate_fixed(data, true, 4, 4096)
  let decompressed = inflate(compressed, decompressed_size=data.length())
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(),
      compressed.length() < data.length(),
    ),
    content=[12, 97, true],
  ) // 'a' and should compress
}

///|
test "deflate_fixed_all_same" {
  let buf = @bytebuf.new(size_hint=100)
  for i = 0; i < 100; i = i + 1 {
    buf.write_byte(b'a')
  }
  let data = buf.contents()
  let compressed = deflate_fixed(data, true, 4, 4096)
  let decompressed = inflate(compressed, decompressed_size=data.length())
  @json.inspect((decompressed.length(), compressed.length() < 20), content=[
    100, true,
  ])
}

///|
test "deflate_dynamic_simple" {
  let data = b"hello"
  let compressed = deflate_dynamic(data, true, 4, 4096)
  let decompressed = inflate(compressed, decompressed_size=data.length())
  @json.inspect((decompressed.length(), decompressed[0].to_int()), content=[
    5, 104,
  ]) // 'h'
}

///|
test "deflate_dynamic_with_repetition" {
  let data = b"abcabcabcabcabcabcabcabc"
  let compressed = deflate_dynamic(data, true, 8, 1024)
  let decompressed = inflate(compressed, decompressed_size=data.length())
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(),
      compressed.length() < data.length(),
    ),
    content=[24, 97, true],
  ) // 'a' and should compress
}

///|
test "deflate_dynamic_highly_compressible" {
  let buf = @bytebuf.new(size_hint=200)
  for i = 0; i < 200; i = i + 1 {
    buf.write_byte(b'a')
  }
  let data = buf.contents()
  let compressed = deflate_dynamic(data, true, 8, 1024)
  let decompressed = inflate(compressed, decompressed_size=data.length())
  @json.inspect((decompressed.length(), compressed.length() < 30), content=[
    200, true,
  ])
}

///|
test "length_to_symbol_basic" {
  @json.inspect(
    (length_to_symbol(3), length_to_symbol(10), length_to_symbol(258)),
    content=[257, 264, 285],
  )
}

///|
test "distance_to_symbol_basic" {
  @json.inspect(
    (distance_to_symbol(1), distance_to_symbol(4), distance_to_symbol(32768)),
    content=[0, 3, 29],
  )
}

///|
test "build_optimal_code_lengths_single" {
  let freqs = Array::make(10, 0)
  freqs[5] = 100
  let lengths = build_optimal_code_lengths(freqs, 9, 15)
  @json.inspect(lengths[5], content=1)
}

///|
test "build_optimal_code_lengths_two" {
  let freqs = Array::make(10, 0)
  freqs[3] = 50
  freqs[7] = 50
  let lengths = build_optimal_code_lengths(freqs, 9, 15)
  @json.inspect((lengths[3], lengths[7]), content=[1, 1])
}

///|
test "distance_to_symbol_ranges" {
  @json.inspect(
    (distance_to_symbol(1), distance_to_symbol(10), distance_to_symbol(32768)),
    content=[0, 6, 29],
  )
}

///|
/// Test distance_to_symbol for all distance ranges
test "distance_to_symbol_all_ranges" {
  // Distance 1-4: symbols 0-3
  @json.inspect(distance_to_symbol(1), content=0)
  @json.inspect(distance_to_symbol(4), content=3)
  // Distance 1025-2048: symbol 20-21
  @json.inspect(distance_to_symbol(1025), content=20)
  @json.inspect(distance_to_symbol(2048), content=21)
  // Distance 2049-4096: symbol 22-23
  @json.inspect(distance_to_symbol(2049), content=22)
  @json.inspect(distance_to_symbol(4096), content=23)
  // Distance 4097-8192: symbol 24-25
  @json.inspect(distance_to_symbol(4097), content=24)
  @json.inspect(distance_to_symbol(8192), content=25)
  // Distance 8193-16384: symbol 26-27
  @json.inspect(distance_to_symbol(8193), content=26)
  @json.inspect(distance_to_symbol(16384), content=27)
  // Distance 16385-32768: symbol 28-29
  @json.inspect(distance_to_symbol(16385), content=28)
  @json.inspect(distance_to_symbol(32768), content=29)
}
