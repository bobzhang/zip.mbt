///|
/// BitWriter tests
test "bitwriter_basic" {
  let buf = @bytebuf.new(size_hint=16)
  let writer = @bitstream.BitWriter::new(buf)
  // Write 3 bits: 0b101 (5)
  writer.write_bits(0b101, 3)
  // Write 5 bits: 0b11010 (26)
  writer.write_bits(0b11010, 5)
  // Total: 8 bits = 0b11010101 = 0xD5 = 213
  writer.flush()
  let result = buf.contents()
  @json.inspect((result.length(), result[0].to_int()), content=[1, 213])
}

///|
test "bitwriter_multi_byte" {
  let buf = @bytebuf.new(size_hint=16)
  let writer = @bitstream.BitWriter::new(buf)
  // Write 0xFF (8 bits)
  writer.write_bits(0xFF, 8)
  // Write 0xAB (8 bits)
  writer.write_bits(0xAB, 8)
  // Write 3 bits: 0b101
  writer.write_bits(0b101, 3)
  writer.flush()
  let result = buf.contents()
  @json.inspect(
    (
      result.length(),
      result[0].to_int(),
      result[1].to_int(),
      result[2].to_int(),
    ),
    content=[3, 255, 171, 5],
  )
}

///|
test "bitwriter_flush_partial" {
  let buf = @bytebuf.new(size_hint=16)
  let writer = @bitstream.BitWriter::new(buf)
  // Write 5 bits (incomplete byte)
  writer.write_bits(0b10101, 5)
  writer.flush()
  let result = buf.contents()
  // Should pad with 3 zero bits: 0b00010101 = 0x15 = 21
  @json.inspect((result.length(), result[0].to_int()), content=[1, 21])
}

///|
test "bitwriter_align_to_byte" {
  let buf = @bytebuf.new(size_hint=16)
  let writer = @bitstream.BitWriter::new(buf)
  writer.write_bits(0xFF, 8)
  writer.write_bits(0b101, 3) // 3 bits pending
  writer.align_to_byte() // Discard the 3 bits
  writer.write_bits(0xAB, 8)
  writer.flush()
  let result = buf.contents()
  // Should have: 0xFF, 0xAB (3 bits discarded)
  @json.inspect((result.length(), result[0].to_int(), result[1].to_int()), content=[
    2, 255, 171,
  ])
}

///|
test "bitwriter_write_byte_aligned" {
  let buf = @bytebuf.new(size_hint=16)
  let writer = @bitstream.BitWriter::new(buf)
  writer.write_bits(0xFF, 8)
  writer.write_byte(0x42) // Should work when aligned
  writer.write_uint16_le(0x1234)
  writer.flush()
  let result = buf.contents()
  @json.inspect(
    (
      result.length(),
      result[0].to_int(),
      result[1].to_int(),
      result[2].to_int(),
      result[3].to_int(),
    ),
    content=[4, 255, 66, 52, 18],
  )
}
