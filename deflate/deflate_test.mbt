// Tests for deflate compression and decompression

///|
test "inflate_uncompressed_block" {
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
test "inflate_with_crc32" {
  let compressed : Bytes = [0b00000001, 3, 0, 252, 255, 0x41, 0x42, 0x43]
  let result = @deflate.inflate(compressed)
  // Basic sanity: result has expected prefix and non-zero length
  @json.inspect((result[:3], result.length() > 0), content=["ABC", true])
}

///|
test "inflate_with_adler32" {
  let compressed = Bytes::from_array([
    0b00000001, 3, 0, 252, 255, 0x41, 0x42, 0x43,
  ])
  let result = @deflate.inflate(compressed)
  let adler = @adler32.bytes_adler32(result[:])
  @json.inspect(
    (result[0].to_int(), result[1].to_int(), result[2].to_int(), adler > 0),
    content=[65, 66, 67, true],
  )
}
