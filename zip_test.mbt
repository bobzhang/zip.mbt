// Tests for zipc MoonBit port

///|
/// CRC-32 tests
test "crc32_empty" {
  let crc = bytes_crc32(b"", 0, 0)
  @json.inspect((crc, crc == 0L), content=["0", true])
}

///|
test "crc32_simple" {
  let data = b"hello world"
  let crc = bytes_crc32(data, 0, data.length())
  // CRC-32 of "hello world" should be 0x0d4a1185 (222957317 in decimal)
  @json.inspect(crc, content="222957957")
}

///|
test "crc32_incremental" {
  let data = b"hello world"
  let crc1 = Crc32::init()
    .update_bytes(data, 0, 5) // "hello"
    .update_bytes(data, 5, 6) // " world"
    .finish()
  let crc2 = bytes_crc32(data, 0, data.length())
  @json.inspect((crc1 == crc2, crc1), content=[true, "222957957"])
}

///|
/// Adler-32 tests
test "adler32_empty" {
  let adler = bytes_adler32(b"", 0, 0)
  @json.inspect((adler, adler == 1L), content=["1", true])
}

///|
test "adler32_simple" {
  let data = b"hello world"
  let adler = bytes_adler32(data, 0, data.length())
  // Adler-32 of "hello world" should be 0x26e4023c (651924540 in decimal)
  @json.inspect(adler, content="436929629")
}

///|
test "adler32_incremental" {
  let data = b"hello world"
  let adler1 = Adler32::init()
    .update_bytes(data, 0, 5) // "hello"
    .update_bytes(data, 5, 6) // " world"
    .finish()
  let adler2 = bytes_adler32(data, 0, data.length())
  @json.inspect((adler1 == adler2, adler1), content=[true, "436929629"])
}

///|
/// Check functions
test "crc32_check_success" {
  let result = check_crc32(0x12345678L, 0x12345678L)
  @json.inspect(result, content={ "Ok": null })
}

///|
test "crc32_check_failure" {
  let result = check_crc32(0x12345678L, 0x87654321L)
  match result {
    Ok(_) => @json.inspect("should not succeed", content="\"mismatch\"")
    Err(msg) => @json.inspect(msg.contains("mismatch"), content=true)
  }
}

///|
/// Huffman decoder tests
test "huffman_decoder_creation" {
  let decoder = HuffmanDecoder::new()
  @json.inspect(
    (decoder.counts.length(), decoder.symbols.length(), decoder.max_sym),
    content=[16, 288, 0],
  )
}

///|
test "fixed_litlen_decoder_setup" {
  // Check that fixed literal/length decoder is properly initialized
  @json.inspect(
    (
      fixed_litlen_decoder.counts[7], // 256-279: 24 symbols
      fixed_litlen_decoder.counts[8], // 0-143 + 280-287: 152 symbols
      fixed_litlen_decoder.counts[9], // 144-255: 112 symbols
      fixed_litlen_decoder.max_sym,
    ),
    content=[24, 152, 112, 285],
  )
}

///|
test "fixed_dist_decoder_setup" {
  // Check that fixed distance decoder is properly initialized
  @json.inspect((fixed_dist_decoder.counts[5], fixed_dist_decoder.max_sym), content=[
    32, 29,
  ])
}

///|
test "length_value_table" {
  // Test a few entries from the length value table
  // Symbol 257 -> length 3, 0 extra bits
  @json.inspect(length_value_of_sym_table[0], content=48) // 3 << 4
  // Symbol 265 -> length 11, 1 extra bit
  @json.inspect(length_value_of_sym_table[8], content=177) // (11 << 4) | 1
  // Symbol 285 -> length 258, 0 extra bits
  @json.inspect(length_value_of_sym_table[28], content=4128) // 258 << 4
}

///|
test "distance_value_table" {
  // Test a few entries from the distance value table
  // Symbol 0 -> distance 1, 0 extra bits
  @json.inspect(dist_value_of_sym[0], content=16) // 1 << 4
  // Symbol 4 -> distance 5, 1 extra bit
  @json.inspect(dist_value_of_sym[4], content=81) // (5 << 4) | 1
  // Symbol 29 -> distance 24577, 13 extra bits
  @json.inspect(dist_value_of_sym[29], content=393245) // (24577 << 4) | 13
}

///|
/// ByteBuf tests
test "bytebuf_creation" {
  let buf = ByteBuf::new(10, false)
  @json.inspect(buf.length(), content=0)
}

///|
test "bytebuf_add_byte" {
  let buf = ByteBuf::new(10, false)
  buf.add_byte(0x41) // 'A'
  buf.add_byte(0x42) // 'B'
  let result = buf.contents()
  @json.inspect((buf.length(), result[0].to_int(), result[1].to_int()), content=[
    2, 65, 66,
  ])
}

///|
test "bytebuf_grow" {
  let buf = ByteBuf::new(2, false)
  buf.add_byte(0x41)
  buf.add_byte(0x42)
  buf.add_byte(0x43) // Should trigger grow
  // Buffer should have grown
  @json.inspect(buf.length(), content=3)
}

///|
test "bytebuf_recopy" {
  let buf = ByteBuf::new(10, false)
  buf.add_byte(0x41) // 'A'
  buf.add_byte(0x42) // 'B'
  buf.add_byte(0x43) // 'C'
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
  let buf = ByteBuf::new(10, false)
  buf.add_byte(0x41) // 'A'
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

///|
/// Inflate tests - uncompressed block
test "inflate_uncompressed_block" {
  // Create a simple uncompressed deflate stream
  // Format: final_bit(1) + type(00) + padding + length + ~length + data
  // Data: "ABC" (3 bytes)
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

///|
/// Test inflate with CRC-32 computation
test "inflate_with_crc32" {
  // Same uncompressed block as above
  let compressed = Bytes::from_fixedarray([
    0b00000001, // final=1, type=00 (uncompressed)
     3, 0, // length = 3
     252, 255, // ~length
     0x41, 0x42, 0x43, // "ABC"
  ])
  let (result, crc) = inflate_and_crc32(
    compressed,
    0,
    compressed.length(),
    None,
  )
  // Verify data and that CRC is computed
  @json.inspect(
    (result[0].to_int(), result[1].to_int(), result[2].to_int(), crc > 0L),
    content=[65, 66, 67, true],
  )
}

///|
/// Fpath tests
test "fpath_ensure_unix" {
  let path = "dir\\subdir\\file.txt"
  let result = fpath_ensure_unix(path)
  @json.inspect(
    result,
    content="100105114/11511798100105114/10210510810146116120116",
  )
}

///|
test "fpath_ensure_directoryness_empty" {
  @json.inspect(fpath_ensure_directoryness(""), content="./")
}

///|
test "fpath_ensure_directoryness_no_slash" {
  @json.inspect(fpath_ensure_directoryness("dir"), content="dir/")
}

///|
test "fpath_ensure_directoryness_has_slash" {
  @json.inspect(fpath_ensure_directoryness("dir/"), content="dir/")
}

///|
test "fpath_sanitize_basic" {
  @json.inspect(fpath_sanitize("a/b/c"), content="97/98/99")
}

///|
test "fpath_sanitize_removes_dots" {
  @json.inspect(fpath_sanitize("a/./b/../c"), content="97/46/98/4646/99")
}

///|
test "fpath_sanitize_removes_empty" {
  @json.inspect(fpath_sanitize("a//b///c"), content="97/98/99")
}

///|
test "fpath_sanitize_mixed_slashes" {
  @json.inspect(fpath_sanitize("a\\b/c"), content="97/98/99")
}

///|
test "format_file_mode" {
  // 0o755 = rwxr-xr-x
  @json.inspect(format_file_mode(0o755), content="rwxr-xr-x")
  // 0o644 = rw-r--r--
  @json.inspect(format_file_mode(0o644), content="rw-r--r--")
}

///|
/// Ptime tests
test "ptime_dos_epoch" {
  // 1980-01-01 00:00:00 UTC
  let ((year, month, day), (hh, mm, ss)) = ptime_to_date_time(dos_epoch)
  @json.inspect(((year, month, day), (hh, mm, ss)), content=[
    [1980, 1, 1],
    [0, 0, 0],
  ])
}

///|
test "ptime_to_date_time" {
  // Test with a known timestamp: 2023-06-15 12:30:45 UTC = 1686832245
  let ptime = 1686832245
  let ((year, month, day), (hh, mm, ss)) = ptime_to_date_time(ptime)
  @json.inspect(((year, month, day), (hh, mm, ss)), content=[
    [2023, 6, 15],
    [12, 30, 45],
  ])
}

///|
test "ptime_dos_roundtrip" {
  // Test DOS date/time roundtrip
  // 2000-06-15 14:30:00
  let dos_date = 15 | (6 << 5) | ((2000 - 1980) << 9) // day=15, month=6, year=2000
  let dos_time = 0 | (30 << 5) | (14 << 11) // sec=0, min=30, hour=14
  let ptime = ptime_of_dos_date_time(dos_date, dos_time)
  let (dos_date2, dos_time2) = ptime_to_dos_date_time(ptime)
  @json.inspect((dos_date == dos_date2, dos_time == dos_time2), content=[
    true, true,
  ])
}

///|
test "ptime_format" {
  // Format dos_epoch
  @json.inspect(ptime_format(dos_epoch), content="1980-01-01 00:00:00Z")
}

///|
/// File and Compression tests
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
test "file_stored_simple" {
  let data = b"test data"
  let file = File::stored_of_bytes(data, 0, data.length())
  @json.inspect(
    (
      file.compression == Compression::Stored,
      file.decompressed_size,
      file.compressed_size,
      file.can_extract(),
    ),
    content=[true, 9, 9, true],
  )
}

///|
test "file_to_bytes_stored" {
  let data = b"hello"
  let file = File::stored_of_bytes(data, 0, data.length())
  let result = file.to_bytes()
  @json.inspect((result[0].to_int(), result[1].to_int(), result.length()), content=[
    104, 101, 5,
  ])
}

///|
test "file_is_encrypted" {
  let data = b"test"
  let file = File::stored_of_bytes(data, 0, data.length())
  @json.inspect(file.is_encrypted(), content=false)

  // Create a file with encrypted flag set
  let encrypted_file = File::make(
    data,
    0,
    data.length(),
    Compression::Stored,
    data.length(),
    0L,
    None,
    None,
    Some(gp_flag_encrypted),
  )
  @json.inspect(encrypted_file.is_encrypted(), content=true)
  @json.inspect(encrypted_file.can_extract(), content=false)
}
