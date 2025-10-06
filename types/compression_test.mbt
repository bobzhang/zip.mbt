///|
/// Compression format tests
test "compression_conversions" {
  // Test to_int
  @json.inspect(@types.Compression::Stored.to_int(), content=0)
  @json.inspect(@types.Compression::Deflate.to_int(), content=8)

  // Test from_int
  @json.inspect(
    @types.Compression::from_int(0) == @types.Compression::Stored,
    content=true,
  )
  @json.inspect(
    @types.Compression::from_int(8) == @types.Compression::Deflate,
    content=true,
  )
  @json.inspect(
    @types.Compression::from_int(99) == @types.Compression::Other(99),
    content=true,
  )
}

///|
test "compression_to_string" {
  @json.inspect(@types.Compression::Stored.to_string(), content="stored")
  @json.inspect(@types.Compression::Deflate.to_string(), content="deflate")
  @json.inspect(@types.Compression::Bzip2.to_string(), content="bzip2")
  @json.inspect(@types.Compression::Other(99).to_string(), content="other(99)")
}
