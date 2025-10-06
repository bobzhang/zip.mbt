///|
/// ByteBuf tests
test "bytebuf_creation" {
  let buf = @buffer.new(size_hint=10)
  @json.inspect(buf.length(), content=0)
}

///|
test "bytebuf_add_byte" {
  let buf = @buffer.new(size_hint=10)
  buf.write_byte(0x41) // 'A'
  buf.write_byte(0x42) // 'B'
  let result = buf.contents()
  @json.inspect((buf.length(), result[0].to_int(), result[1].to_int()), content=[
    2, 65, 66,
  ])
}

///|
test "bytebuf_grow" {
  let buf = @buffer.new(size_hint=2)
  buf.write_byte(0x41)
  buf.write_byte(0x42)
  buf.write_byte(0x43) // Should trigger grow
  // Buffer should have grown
  @json.inspect(buf.length(), content=3)
}

///|
test "bytebuf_recopy" {
  let buf = @buffer.new(size_hint=10)
  buf.write_byte(0x41) // 'A'
  buf.write_byte(0x42) // 'B'
  buf.write_byte(0x43) // 'C'
  // Copy bytes 0-1 (AB) to the end
  buf.recopy(0, 2)
  let result = buf.contents()
  @json.inspect(
    (
      buf.length(),
      result[0].to_int(),
      result[1].to_int(),
      result[2].to_int(),
      result[3].to_int(),
      result[4].to_int(),
    ),
    content=[5, 65, 66, 67, 65, 66],
  )
}

///|
/// ByteBuf recopy overlapping (RLE pattern)
test "bytebuf_recopy_overlapping" {
  let buf = @buffer.new(size_hint=10)
  buf.write_byte(0x41) // 'A'
  // Copy 1 byte from position 0, repeated 5 times (overlapping)
  buf.recopy(0, 5)
  let result = buf.contents()
  // Should produce "AAAAAA" (6 total A's)
  @json.inspect(
    (
      buf.length(),
      result[0].to_int(),
      result[1].to_int(),
      result[2].to_int(),
      result[5].to_int(),
    ),
    content=[6, 65, 65, 65, 65],
  )
}
