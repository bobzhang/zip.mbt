///|
fn main {
  // Test CRC-32
  let data = b"hello world"
  let crc = @lib.bytes_crc32(data, 0, data.length())
  println("CRC-32 of 'hello world': \{crc}")
}
