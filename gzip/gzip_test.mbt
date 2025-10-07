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
