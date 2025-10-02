///|
/// Compression format tests
test "compression_conversions" {
  // Test to_int
  @json.inspect(Compression::Stored.to_int(), content=0)
  @json.inspect(Compression::Deflate.to_int(), content=8)

  // Test from_int
  @json.inspect(Compression::from_int(0) == Compression::Stored, content=true)
  @json.inspect(Compression::from_int(8) == Compression::Deflate, content=true)
  @json.inspect(
    Compression::from_int(99) == Compression::Other(99),
    content=true,
  )
}

///|
test "compression_to_string" {
  @json.inspect(Compression::Stored.to_string(), content="stored")
  @json.inspect(Compression::Deflate.to_string(), content="deflate")
  @json.inspect(Compression::Bzip2.to_string(), content="bzip2")
  @json.inspect(Compression::Other(99).to_string(), content="other(99)")
}
