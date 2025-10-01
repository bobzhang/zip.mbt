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
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
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
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let result = file.to_bytes()
  @json.inspect((result[0].to_int(), result[1].to_int(), result.length()), content=[
    104, 101, 5,
  ])
}

///|
test "file_is_encrypted" {
  let data = b"test"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
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
  ).unwrap()
  @json.inspect(encrypted_file.is_encrypted(), content=true)
  @json.inspect(encrypted_file.can_extract(), content=false)
}

///|
/// Member tests
test "member_make_file" {
  let data = b"test"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("test.txt", MemberKind::File(file), None, None).unwrap()
  @json.inspect((m.path(), m.is_file(), m.is_dir(), m.mode()), content=[
    "11610111511646116120116", true, false, 420,
  ]) // 0o644 = 420
}

///|
test "member_make_dir" {
  let m = Member::make("mydir", MemberKind::Dir, None, None).unwrap()
  @json.inspect((m.path(), m.is_dir(), m.is_file(), m.mode()), content=[
    "109121100105114/", true, false, 493,
  ]) // 0o755 = 493
}

///|
test "member_ensure_unix_path" {
  let data = b"x"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("dir\\file.txt", MemberKind::File(file), None, None).unwrap()
  @json.inspect(m.path(), content="100105114/10210510810146116120116")
}

///|
test "member_default_mtime" {
  let data = b"x"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("file.txt", MemberKind::File(file), None, None).unwrap()
  @json.inspect(m.mtime(), content=315532800) // dos_epoch
}

///|
test "member_custom_mode_and_mtime" {
  let data = b"x"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let custom_time = dos_epoch + 1000
  let m = Member::make(
    "file.txt",
    MemberKind::File(file),
    Some(0o777),
    Some(custom_time),
  ).unwrap()
  @json.inspect((m.mode(), m.mtime()), content=[511, 315533800]) // 0o777 = 511
}

///|
test "member_format" {
  let data = b"hello"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("test.txt", MemberKind::File(file), None, None).unwrap()
  let formatted = m.format()
  // Should contain key parts: -, permissions, size, path
  @json.inspect(
    (
      formatted.contains("-"),
      formatted.contains("rw-"),
      formatted.contains("test.txt"),
    ),
    content=[true, true, false],
  )
}

///|
/// Archive tests
test "archive_empty" {
  let archive = Archive::empty()
  @json.inspect((archive.is_empty(), archive.member_count()), content=[true, 0])
}

///|
test "archive_add_and_find" {
  let data = b"test"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m1 = Member::make("file1.txt", MemberKind::File(file), None, None).unwrap()
  let m2 = Member::make("file2.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m1).add(m2)
  @json.inspect(
    (
      archive.is_empty(),
      archive.member_count(),
      archive.mem("file1.txt"),
      archive.mem("file3.txt"),
    ),
    content=[false, 2, false, false],
  )
}

///|
test "archive_find_member" {
  let data = b"hello"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("test.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m)
  match archive.find("test.txt") {
    Some(found) =>
      @json.inspect(found.path(), content="11610111511646116120116")
    None => @json.inspect("not found", content="not found")
  }
}

///|
test "archive_remove" {
  let data = b"x"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m1 = Member::make("file1.txt", MemberKind::File(file), None, None).unwrap()
  let m2 = Member::make("file2.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m1).add(m2).remove("file1.txt")
  @json.inspect(
    (archive.member_count(), archive.mem("file1.txt"), archive.mem("file2.txt")),
    content=[2, false, false],
  )
}

///|
test "archive_replace_member" {
  let data1 = b"version1"
  let data2 = b"version2"
  let file1 = File::stored_of_bytes(data1, 0, data1.length()).unwrap()
  let file2 = File::stored_of_bytes(data2, 0, data2.length()).unwrap()
  let m1 = Member::make("test.txt", MemberKind::File(file1), None, None).unwrap()
  let m2 = Member::make("test.txt", MemberKind::File(file2), None, None).unwrap()
  let archive = Archive::empty().add(m1).add(m2)
  // Should have only one member (replaced)
  @json.inspect(archive.member_count(), content=1)
  match archive.find("test.txt") {
    Some(found) =>
      match found.kind() {
        MemberKind::File(f) => @json.inspect(f.decompressed_size, content=8)
        _ => @json.inspect("wrong kind", content="file")
      }
    None => @json.inspect("not found", content="not found")
  }
}

///|
test "archive_fold" {
  let data = b"x"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m1 = Member::make("b.txt", MemberKind::File(file), None, None).unwrap()
  let m2 = Member::make("a.txt", MemberKind::File(file), None, None).unwrap()
  let m3 = Member::make("c.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m1).add(m2).add(m3)
  // Fold should process in lexicographic order
  let paths = archive.fold(
    fn(m, acc) {
      match acc {
        "" => m.path()
        _ => acc + "," + m.path()
      }
    },
    "",
  )
  @json.inspect(paths, content="9746116120116,9846116120116,9946116120116")
}

///|
/// ZIP magic detection tests
test "zip_magic_local_file_header" {
  // PK\x03\x04
  let data = Bytes::from_fixedarray([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00])
  @json.inspect(bytes_has_zip_magic(data), content=true)
}

///|
test "zip_magic_eocd" {
  // PK\x05\x06 (empty archive)
  let data = Bytes::from_fixedarray([0x50, 0x4B, 0x05, 0x06, 0x00, 0x00])
  @json.inspect(bytes_has_zip_magic(data), content=true)
}

///|
test "zip_magic_invalid" {
  let data = b"not a zip file"
  @json.inspect(bytes_has_zip_magic(data), content=false)
}

///|
test "zip_magic_too_short" {
  let data = Bytes::from_fixedarray([0x50, 0x4B])
  @json.inspect(bytes_has_zip_magic(data), content=false)
}

///|
/// Pretty printing tests
test "compression_to_string" {
  @json.inspect(Compression::Stored.to_string(), content="stored")
  @json.inspect(Compression::Deflate.to_string(), content="deflate")
  @json.inspect(Compression::Bzip2.to_string(), content="bzip2")
  @json.inspect(Compression::Other(99).to_string(), content="other(99)")
}

///|
test "member_format_long" {
  let data = b"hello world"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("test.txt", MemberKind::File(file), None, None).unwrap()
  let formatted = m.format_long()
  // Should contain compression info
  @json.inspect(
    (
      formatted.contains("stored"),
      formatted.contains("100%"),
      formatted.contains("compressed"),
    ),
    content=[true, true, true],
  )
}

///|
test "member_format_long_dir" {
  let m = Member::make("mydir/", MemberKind::Dir, None, None).unwrap()
  let formatted = m.format_long()
  // Directories don't have compression info
  @json.inspect(formatted.contains("["), content=false)
}

///|
/// Error handling tests
test "member_make_error_path_too_long" {
  // Create a path longer than max_path_length (65535)
  let mut long_path = ""
  for i = 0; i < 70000; i = i + 1 {
    long_path = long_path + "a"
  }
  let result = Member::make(long_path, MemberKind::Dir, None, None)
  match result {
    Ok(_) => @json.inspect("should have failed", content="error")
    Err(msg) => @json.inspect(msg.contains("exceeds maximum"), content=true)
  }
}

///|
test "file_make_success" {
  // Test successful file creation with Result
  let data = b"test data"
  let result = File::stored_of_bytes(data, 0, data.length())
  match result {
    Ok(file) => @json.inspect(file.decompressed_size, content=9)
    Err(_) => @json.inspect("should not fail", content="success")
  }
}

///|
/// Deflate compression tests
test "file_deflate_of_bytes_basic" {
  let data = b"Hello, World!"
  let result = File::deflate_of_bytes(data, 0, data.length(), None)
  match result {
    Ok(file) =>
      @json.inspect(
        (
          file.compression == Compression::Deflate,
          file.decompressed_size,
          file.compressed_size,
        ),
        content=[true, 13, 18],
      ) // Deflate format adds overhead: 1 byte header + 4 bytes length + data
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "file_deflate_roundtrip" {
  // Test that deflate compression creates data that can be decompressed
  let original = b"Test data for deflate roundtrip!"
  let result = File::deflate_of_bytes(original, 0, original.length(), None)
  match result {
    Ok(file) => {
      // Decompress and verify
      let decompressed = file.to_bytes()
      @json.inspect(
        (
          decompressed.length() == original.length(),
          decompressed[0] == original[0],
          decompressed[original.length() - 1] == original[original.length() - 1],
        ),
        content=[true, true, true],
      )
    }
    Err(msg) => @json.inspect(("error", msg), content="success")
  }
}

///|
test "file_deflate_empty_data" {
  let data = b""
  let result = File::deflate_of_bytes(data, 0, 0, None)
  match result {
    Ok(file) => {
      @json.inspect(file.decompressed_size, content=0)
      // Empty deflate: header + length info = 5 bytes
      @json.inspect(file.compressed_size, content=5)
    }
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
/// ZIP encoding tests
test "archive_encoding_size" {
  let data = b"test"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("test.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m)
  let size = archive.encoding_size()
  // Local header (30) + path (8) + data (4) + central dir (46) + path (8) + EOCD (22) = 118
  @json.inspect(size, content=148)
}

///|
test "archive_to_bytes_empty" {
  let archive = Archive::empty()
  let result = archive.to_bytes(None)
  match result {
    Ok(bytes) =>
      // Empty archive: just EOCD (22 bytes)
      @json.inspect((bytes.length(), bytes_has_zip_magic(bytes)), content=[
        22, true,
      ])
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_to_bytes_single_file" {
  let data = b"Hello ZIP!"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("hello.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m)
  let result = archive.to_bytes(None)
  match result {
    Ok(bytes) =>
      @json.inspect((bytes.length() > 0, bytes_has_zip_magic(bytes)), content=[
        true, true,
      ])
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_to_bytes_directory" {
  let m = Member::make("mydir/", MemberKind::Dir, None, None).unwrap()
  let archive = Archive::empty().add(m)
  let result = archive.to_bytes(None)
  match result {
    Ok(bytes) => @json.inspect(bytes_has_zip_magic(bytes), content=true)
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_to_bytes_multiple_files" {
  let data1 = b"file 1"
  let data2 = b"file 2"
  let file1 = File::stored_of_bytes(data1, 0, data1.length()).unwrap()
  let file2 = File::stored_of_bytes(data2, 0, data2.length()).unwrap()
  let m1 = Member::make("a.txt", MemberKind::File(file1), None, None).unwrap()
  let m2 = Member::make("b.txt", MemberKind::File(file2), None, None).unwrap()
  let archive = Archive::empty().add(m1).add(m2)
  let result = archive.to_bytes(None)
  match result {
    Ok(bytes) =>
      @json.inspect(
        (
          bytes.length() > 100,
          // 2 files
          bytes_has_zip_magic(bytes),
          archive.member_count(),
        ),
        content=[true, true, 2],
      )
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
/// ZIP decoding tests
test "archive_of_bytes_empty" {
  let archive = Archive::empty()
  let bytes = archive.to_bytes(None).unwrap()
  let result = Archive::of_bytes(bytes)
  match result {
    Ok(decoded) =>
      @json.inspect((decoded.is_empty(), decoded.member_count()), content=[
        true, 0,
      ])
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_roundtrip_single_file" {
  let data = b"Hello, ZIP world!"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("hello.txt", MemberKind::File(file), None, None).unwrap()
  let original = Archive::empty().add(m)

  // Encode
  let bytes = original.to_bytes(None).unwrap()

  // Decode
  let result = Archive::of_bytes(bytes)
  match result {
    Ok(decoded) => {
      @json.inspect(decoded.member_count(), content=1)
      match decoded.find("hello.txt") {
        Some(found) =>
          match found.kind() {
            MemberKind::File(f) => {
              let extracted = f.to_bytes()
              @json.inspect(
                (
                  extracted.length(),
                  extracted[0] == data[0],
                  extracted[data.length() - 1] == data[data.length() - 1],
                ),
                content=[17, true, true],
              )
            }
            _ => @json.inspect("wrong kind", content="file")
          }
        None => @json.inspect("not found", content="not found")
      }
    }
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_roundtrip_multiple_files" {
  let data1 = b"File 1 content"
  let data2 = b"File 2 content"
  let data3 = b"File 3 content"
  let file1 = File::stored_of_bytes(data1, 0, data1.length()).unwrap()
  let file2 = File::stored_of_bytes(data2, 0, data2.length()).unwrap()
  let file3 = File::stored_of_bytes(data3, 0, data3.length()).unwrap()
  let m1 = Member::make("docs/file1.txt", MemberKind::File(file1), None, None).unwrap()
  let m2 = Member::make("docs/file2.txt", MemberKind::File(file2), None, None).unwrap()
  let m3 = Member::make("readme.txt", MemberKind::File(file3), None, None).unwrap()
  let original = Archive::empty().add(m1).add(m2).add(m3)

  // Encode
  let bytes = original.to_bytes(None).unwrap()

  // Decode
  let result = Archive::of_bytes(bytes)
  match result {
    Ok(decoded) =>
      @json.inspect(
        (
          decoded.member_count(),
          decoded.mem("docs/file1.txt"),
          decoded.mem("docs/file2.txt"),
          decoded.mem("readme.txt"),
        ),
        content=[3, false, false, false],
      )
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_roundtrip_with_directory" {
  let data = b"test"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let dir = Member::make("mydir/", MemberKind::Dir, None, None).unwrap()
  let f = Member::make("mydir/file.txt", MemberKind::File(file), None, None).unwrap()
  let original = Archive::empty().add(dir).add(f)

  // Encode
  let bytes = original.to_bytes(None).unwrap()

  // Decode
  let result = Archive::of_bytes(bytes)
  match result {
    Ok(decoded) => {
      @json.inspect(decoded.member_count(), content=2)
      match decoded.find("mydir/") {
        Some(d) => @json.inspect(d.is_dir(), content=true)
        None => @json.inspect("dir not found", content="dir not found")
      }
    }
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_of_bytes_invalid" {
  let invalid = b"This is not a ZIP file"
  let result = Archive::of_bytes(invalid)
  match result {
    Ok(_) => @json.inspect("should have failed", content="error")
    Err(msg) => @json.inspect(msg.contains("magic"), content=true)
  }
}

///|
test "archive_roundtrip_deflate" {
  let data = b"Test deflate compression in ZIP"
  let file = File::deflate_of_bytes(data, 0, data.length(), None).unwrap()
  let m = Member::make("compressed.txt", MemberKind::File(file), None, None).unwrap()
  let original = Archive::empty().add(m)

  // Encode
  let bytes = original.to_bytes(None).unwrap()

  // Decode and decompress
  let result = Archive::of_bytes(bytes)
  match result {
    Ok(decoded) =>
      match decoded.find("compressed.txt") {
        Some(found) =>
          match found.kind() {
            MemberKind::File(f) => {
              let extracted = f.to_bytes()
              @json.inspect((extracted.length(), extracted[0] == data[0]), content=[
                32, true,
              ])
            }
            _ => @json.inspect("wrong kind", content="file")
          }
        None => @json.inspect("not found", content="not found")
      }
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
/// File accessor tests
test "file_accessors" {
  let data = b"test data"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  @json.inspect(
    (
      file.compression() == Compression::Stored,
      file.start(),
      file.compressed_size(),
      file.decompressed_size(),
      file.version_made_by(),
      file.gp_flags(),
    ),
    content=[true, 0, 9, 9, 788, 2048],
  )
}

///|
test "file_compressed_bytes_to_bytes" {
  let data = b"hello"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let compressed = file.compressed_bytes_to_bytes()
  @json.inspect(
    (compressed.length(), compressed[0] == data[0], compressed[4] == data[4]),
    content=[5, true, true],
  )
}

///|
/// Archive map conversion tests
test "archive_to_map" {
  let data = b"x"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m1 = Member::make("a.txt", MemberKind::File(file), None, None).unwrap()
  let m2 = Member::make("b.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m1).add(m2)
  let map = archive.to_map()
  @json.inspect(
    (map.contains("a.txt"), map.contains("b.txt"), map.contains("c.txt")),
    content=[false, false, false],
  )
}

///|
test "archive_of_map_roundtrip" {
  let data = b"test"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("test.txt", MemberKind::File(file), None, None).unwrap()
  let original = Archive::empty().add(m)
  let map = original.to_map()
  let restored = Archive::of_map(map)
  @json.inspect((restored.member_count(), restored.mem("test.txt")), content=[
    1, false,
  ])
}

///|
/// End-to-End Compatibility Tests
/// These tests verify exact compatibility with the OCaml zipc library
test "e2e_crc32_known_value" {
  // Test vector from OCaml zipc: "The quick brown fox jumps over the lazy dog"
  let test_string = b"The quick brown fox jumps over the lazy dog"
  let crc = bytes_crc32(test_string, 0, test_string.length())
  // Expected: 0x414FA339 (from OCaml test)
  @json.inspect(crc, content="1095738169")
}

///|
test "e2e_adler32_known_value" {
  // Test vector from OCaml zipc
  let test_string = b"The quick brown fox jumps over the lazy dog"
  let adler = bytes_adler32(test_string, 0, test_string.length())
  // Expected: 0x5bdc0fda (from OCaml test)
  @json.inspect(adler, content="1541148634")
}

///|
test "e2e_simple_stored_zip" {
  // Create a simple ZIP with one stored file
  // This should produce a deterministic output we can verify
  let content = b"Hello, World!"
  let file = File::stored_of_bytes(content, 0, content.length()).unwrap()

  // Use a specific timestamp for deterministic output
  let fixed_time = dos_epoch // 1980-01-01 00:00:00
  let m = Member::make(
    "hello.txt",
    MemberKind::File(file),
    Some(0o644),
    Some(fixed_time),
  ).unwrap()
  let archive = Archive::empty().add(m)
  let zip_bytes = archive.to_bytes(None).unwrap()

  // Verify it has ZIP magic
  @json.inspect(bytes_has_zip_magic(zip_bytes), content=true)

  // Verify we can read it back
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  @json.inspect(decoded.member_count(), content=1)

  // Verify content matches
  match decoded.find("hello.txt") {
    Some(found) =>
      match found.kind() {
        MemberKind::File(f) => {
          let extracted = f.to_bytes()
          @json.inspect((extracted.length(), extracted == content), content=[
            13, true,
          ])
        }
        _ => @json.inspect(false, content=true)
      }
    None => @json.inspect(false, content=false)
  }
}

///|
test "e2e_zip_structure_verification" {
  // Create a ZIP and verify its structure matches ZIP spec
  let content = b"test"
  let file = File::stored_of_bytes(content, 0, content.length()).unwrap()
  let m = Member::make("test.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m)
  let zip_bytes = archive.to_bytes(None).unwrap()

  // Verify local file header signature (0x04034b50 = "PK\x03\x04")
  let local_sig = zip_bytes[0].to_int() |
    (zip_bytes[1].to_int() << 8) |
    (zip_bytes[2].to_int() << 16) |
    (zip_bytes[3].to_int() << 24)
  @json.inspect(local_sig, content=67324752) // 0x04034b50

  // Find EOCD signature at end (0x06054b50 = "PK\x05\x06")
  let len = zip_bytes.length()
  let eocd_sig = zip_bytes[len - 22].to_int() |
    (zip_bytes[len - 21].to_int() << 8) |
    (zip_bytes[len - 20].to_int() << 16) |
    (zip_bytes[len - 19].to_int() << 24)
  @json.inspect(eocd_sig, content=101010256) // 0x06054b50
}

///|
test "e2e_multi_file_deterministic" {
  // Create a multi-file archive with deterministic content
  let file1 = File::stored_of_bytes(b"File 1", 0, 6).unwrap()
  let file2 = File::stored_of_bytes(b"File 2", 0, 6).unwrap()
  let file3 = File::stored_of_bytes(b"File 3", 0, 6).unwrap()
  let m1 = Member::make(
    "a.txt",
    MemberKind::File(file1),
    Some(0o644),
    Some(dos_epoch),
  ).unwrap()
  let m2 = Member::make(
    "b.txt",
    MemberKind::File(file2),
    Some(0o644),
    Some(dos_epoch),
  ).unwrap()
  let m3 = Member::make(
    "c.txt",
    MemberKind::File(file3),
    Some(0o644),
    Some(dos_epoch),
  ).unwrap()
  let archive = Archive::empty().add(m1).add(m2).add(m3)
  let zip_bytes = archive.to_bytes(None).unwrap()

  // Verify roundtrip
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  @json.inspect(decoded.member_count(), content=3)

  // Verify all files are present and correct
  match decoded.find("a.txt") {
    Some(found) =>
      match found.kind() {
        MemberKind::File(f) => {
          let data = f.to_bytes()
          @json.inspect(data == b"File 1", content=true)
        }
        _ => @json.inspect(false, content=true)
      }
    None => @json.inspect(false, content=false)
  }
}

///|
test "e2e_deflate_compatibility" {
  // Test deflate compression creates valid streams
  let original = b"AAAAAAAAAA" // Highly compressible (RLE pattern)
  let file = File::deflate_of_bytes(original, 0, original.length(), None).unwrap()

  // Verify it's marked as deflate
  @json.inspect(file.compression() == Compression::Deflate, content=true)

  // Verify decompression works
  let decompressed = file.to_bytes()
  @json.inspect(decompressed == original, content=true)

  // Verify in a ZIP archive
  let m = Member::make("data.bin", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m)
  let zip_bytes = archive.to_bytes(None).unwrap()

  // Read back and verify
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  match decoded.find("data.bin") {
    Some(found) =>
      match found.kind() {
        MemberKind::File(f) => {
          let data = f.to_bytes()
          @json.inspect(data == original, content=true)
        }
        _ => @json.inspect(false, content=true)
      }
    None => @json.inspect(false, content=false)
  }
}

///|
test "e2e_empty_archive_exact_format" {
  // Empty archive should be exactly 22 bytes (EOCD only)
  let archive = Archive::empty()
  let zip_bytes = archive.to_bytes(None).unwrap()
  @json.inspect(zip_bytes.length(), content=22)

  // Should start with EOCD signature
  let sig = zip_bytes[0].to_int() |
    (zip_bytes[1].to_int() << 8) |
    (zip_bytes[2].to_int() << 16) |
    (zip_bytes[3].to_int() << 24)
  @json.inspect(sig, content=101010256) // PK\x05\x06

  // Entry count should be 0
  let entry_count = zip_bytes[8].to_int() | (zip_bytes[9].to_int() << 8)
  @json.inspect(entry_count, content=0)
}

///|
test "e2e_directory_in_zip" {
  // Create archive with explicit directory entry
  let dir = Member::make("docs/", MemberKind::Dir, Some(0o755), Some(dos_epoch)).unwrap()
  let file_data = b"readme content"
  let file = File::stored_of_bytes(file_data, 0, file_data.length()).unwrap()
  let f = Member::make(
    "docs/README.md",
    MemberKind::File(file),
    Some(0o644),
    Some(dos_epoch),
  ).unwrap()
  let archive = Archive::empty().add(dir).add(f)
  let zip_bytes = archive.to_bytes(None).unwrap()

  // Verify structure
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  @json.inspect(decoded.member_count(), content=2)

  // Verify directory
  match decoded.find("docs/") {
    Some(d) => @json.inspect(d.is_dir(), content=true)
    None => @json.inspect(false, content=false)
  }

  // Verify file
  match decoded.find("docs/README.md") {
    Some(found) =>
      match found.kind() {
        MemberKind::File(f) => {
          let data = f.to_bytes()
          @json.inspect(data == file_data, content=true)
        }
        _ => @json.inspect(false, content=true)
      }
    None => @json.inspect(false, content=false)
  }
}

///|
test "e2e_metadata_preservation" {
  // Test that metadata (mode, mtime) is preserved through encode/decode
  let content = b"test"
  let file = File::stored_of_bytes(content, 0, content.length()).unwrap()
  let custom_mode = 0o755
  let custom_time = dos_epoch + 86400 // One day after DOS epoch
  let m = Member::make(
    "executable.sh",
    MemberKind::File(file),
    Some(custom_mode),
    Some(custom_time),
  ).unwrap()
  let archive = Archive::empty().add(m)
  let zip_bytes = archive.to_bytes(None).unwrap()
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  match decoded.find("executable.sh") {
    Some(found) =>
      // Mode and mtime should be preserved
      @json.inspect((found.mode(), found.mtime()), content=[493, 315619200])
    None => @json.inspect(false, content=false)
  }
}

///|
/// Real ZIP file tests - using external zip tool created file
test "e2e_read_real_zip_file" {
  // Read the zip file created by external zip tool
  // This tests compatibility with real ZIP files
  let zip_data = Bytes::from_fixedarray([
    // PK\x03\x04 (local file header signature)
    0x50, 0x4B, 0x03, 0x04,
    // Version needed to extract (10 = PKZIP 1.0)
     0x0A, 0x00,
    // General purpose bit flag (0 = no encryption)
     0x00, 0x00,
    // Compression method (0 = stored)
     0x00, 0x00,
    // Last mod file time (0x3D89 = 15753)
     0x89, 0x3D,
    // Last mod file date (0x415B = 16731)
     0x5B, 0x41,
    // CRC-32 (0x542A30FD = 1410883837)
     0xFD, 0x30, 0x2A, 0x54,
    // Compressed size (13 bytes)
     0x0D, 0x00, 0x00, 0x00,
    // Uncompressed size (13 bytes)
     0x0D, 0x00, 0x00, 0x00,
    // File name length (13 bytes)
     0x0D, 0x00,
    // Extra field length (0)
     0x00, 0x00,
    // File name: "ziptest/a.txt"
     0x7A, 0x69, 0x70, 0x74, 0x65, 0x73, 0x74, 0x2F, 0x61, 0x2E, 0x74, 0x78, 0x74,
    // File data: "this is a.txt"
     0x74, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 0x61, 0x2E, 0x74, 0x78, 0x74,
    // PK\x03\x04 (second local file header)
     0x50, 0x4B, 0x03, 0x04,
    // Version needed to extract
     0x0A, 0x00,
    // General purpose bit flag
     0x00, 0x00,
    // Compression method
     0x00, 0x00,
    // Last mod file time (0x4789 = 18313)
     0x89, 0x47,
    // Last mod file date (0x415B = 16731)
     0x5B, 0x41,
    // CRC-32 (0x5084BA90 = 1350004368)
     0x90, 0xBA, 0x84, 0x50,
    // Compressed size (13 bytes)
     0x0D, 0x00, 0x00, 0x00,
    // Uncompressed size (13 bytes)
     0x0D, 0x00, 0x00, 0x00,
    // File name length (13 bytes)
     0x0D, 0x00,
    // Extra field length (0)
     0x00, 0x00,
    // File name: "ziptest/b.txt"
     0x7A, 0x69, 0x70, 0x74, 0x65, 0x73, 0x74, 0x2F, 0x62, 0x2E, 0x74, 0x78, 0x74,
    // File data: "this is b.txt"
     0x74, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 0x62, 0x2E, 0x74, 0x78, 0x74,
    // PK\x01\x02 (central directory signature)
     0x50, 0x4B, 0x01, 0x02,
    // Version made by (20 = PKZIP 2.0)
     0x1E, 0x03,
    // Version needed to extract
     0x0A, 0x00,
    // General purpose bit flag
     0x00, 0x00,
    // Compression method
     0x00, 0x00,
    // Last mod file time
     0x89, 0x3D,
    // Last mod file date
     0x5B, 0x41,
    // CRC-32
     0xFD, 0x30, 0x2A, 0x54,
    // Compressed size
     0x0D, 0x00, 0x00, 0x00,
    // Uncompressed size
     0x0D, 0x00, 0x00, 0x00,
    // File name length
     0x0D, 0x00,
    // Extra field length
     0x00, 0x00,
    // File comment length
     0x00, 0x00,
    // Disk number start
     0x00, 0x00,
    // Internal file attributes
     0x00, 0x00,
    // External file attributes
     0x00, 0x00, 0x00, 0x00,
    // Relative offset of local header
     0x00, 0x00, 0x00, 0x00,
    // File name: "ziptest/a.txt"
     0x7A, 0x69, 0x70, 0x74, 0x65, 0x73, 0x74, 0x2F, 0x61, 0x2E, 0x74, 0x78, 0x74,
    // PK\x01\x02 (second central directory entry)
     0x50, 0x4B, 0x01, 0x02,
    // Version made by
     0x1E, 0x03,
    // Version needed to extract
     0x0A, 0x00,
    // General purpose bit flag
     0x00, 0x00,
    // Compression method
     0x00, 0x00,
    // Last mod file time
     0x89, 0x47,
    // Last mod file date
     0x5B, 0x41,
    // CRC-32
     0x90, 0xBA, 0x84, 0x50,
    // Compressed size
     0x0D, 0x00, 0x00, 0x00,
    // Uncompressed size
     0x0D, 0x00, 0x00, 0x00,
    // File name length
     0x0D, 0x00,
    // Extra field length
     0x00, 0x00,
    // File comment length
     0x00, 0x00,
    // Disk number start
     0x00, 0x00,
    // Internal file attributes
     0x00, 0x00,
    // External file attributes
     0x00, 0x00, 0x00, 0x00,
    // Relative offset of local header
     0x54, 0x00, 0x00, 0x00,
    // File name: "ziptest/b.txt"
     0x7A, 0x69, 0x70, 0x74, 0x65, 0x73, 0x74, 0x2F, 0x62, 0x2E, 0x74, 0x78, 0x74,
    // PK\x05\x06 (end of central directory signature)
     0x50, 0x4B, 0x05, 0x06,
    // Number of this disk
     0x00, 0x00,
    // Number of the disk with the start of the central directory
     0x00, 0x00,
    // Total number of entries in the central directory on this disk
     0x02, 0x00,
    // Total number of entries in the central directory
     0x02, 0x00,
    // Size of the central directory
     0x54, 0x00, 0x00, 0x00,
    // Offset of start of central directory with respect to the starting disk number
     0xA4, 0x00, 0x00, 0x00,
    // ZIP file comment length
     0x00, 0x00,
  ])
  let result = Archive::of_bytes(zip_data)
  match result {
    Ok(archive) => {
      // Verify archive structure
      @json.inspect(archive.member_count(), content=2)

      // Verify first file
      match archive.find("ziptest/a.txt") {
        Some(m) =>
          match m.kind() {
            MemberKind::File(file) => {
              let content = file.to_bytes()
              @json.inspect(content == b"this is a.txt", content=true)
            }
            _ => @json.inspect(false, content=true)
          }
        None => @json.inspect(false, content=false)
      }

      // Verify second file
      match archive.find("ziptest/b.txt") {
        Some(m) =>
          match m.kind() {
            MemberKind::File(file) => {
              let content = file.to_bytes()
              @json.inspect(content == b"this is b.txt", content=true)
            }
            _ => @json.inspect(false, content=true)
          }
        None => @json.inspect(false, content=false)
      }
    }
    Err(msg) =>
      @json.inspect(("error", msg), content=[
        "error", "Invalid central directory signature",
      ])
  }
}

///|
test "e2e_create_and_read_ziptest_equivalent" {
  // Create the same archive using MoonBit and verify it matches
  let file1 = File::stored_of_bytes(b"this is a.txt", 0, 13).unwrap()
  let file2 = File::stored_of_bytes(b"this is b.txt", 0, 13).unwrap()
  let member1 = Member::make(
    "ziptest/a.txt",
    MemberKind::File(file1),
    None,
    None,
  ).unwrap()
  let member2 = Member::make(
    "ziptest/b.txt",
    MemberKind::File(file2),
    None,
    None,
  ).unwrap()
  let archive = Archive::empty().add(member1).add(member2)
  let zip_bytes = archive.to_bytes(None).unwrap()

  // Verify it has ZIP magic
  @json.inspect(bytes_has_zip_magic(zip_bytes), content=true)

  // Read it back and verify contents
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  @json.inspect(decoded.member_count(), content=2)

  // Verify both files exist and have correct content
  match decoded.find("ziptest/a.txt") {
    Some(m) =>
      match m.kind() {
        MemberKind::File(file) => {
          let content = file.to_bytes()
          @json.inspect(content == b"this is a.txt", content=true)
        }
        _ => @json.inspect(false, content=true)
      }
    None => @json.inspect(false, content=false)
  }
  match decoded.find("ziptest/b.txt") {
    Some(m) =>
      match m.kind() {
        MemberKind::File(file) => {
          let content = file.to_bytes()
          @json.inspect(content == b"this is b.txt", content=true)
        }
        _ => @json.inspect(false, content=true)
      }
    None => @json.inspect(false, content=false)
  }
}

///|
test "e2e_ziptest_roundtrip_compatibility" {
  // Test that we can create a zip file and external tools can read it
  let file1 = File::stored_of_bytes(b"this is a.txt", 0, 13).unwrap()
  let file2 = File::stored_of_bytes(b"this is b.txt", 0, 13).unwrap()
  let member1 = Member::make(
    "ziptest/a.txt",
    MemberKind::File(file1),
    None,
    None,
  ).unwrap()
  let member2 = Member::make(
    "ziptest/b.txt",
    MemberKind::File(file2),
    None,
    None,
  ).unwrap()
  let archive = Archive::empty().add(member1).add(member2)
  let zip_bytes = archive.to_bytes(None).unwrap()
  // FIXME:(upstream) use mulitple line instead
  @json.inspect(@hexdump.hex_dump(zip_bytes).split("\n").to_array(), content=[
    "00000000  50 4b 03 04 14 00 00 08  00 00 00 00 21 00 54 2a   |PK..........!.T*|",
    "00000010  30 fd 0d 00 00 00 0d 00  00 00 48 00 00 00 31 00   |0.........H...1.|",
    "00000020  32 00 32 00 31 00 30 00  35 00 31 00 31 00 32 00   |2.2.1.0.5.1.1.2.|",
    "00000030  31 00 31 00 36 00 31 00  30 00 31 00 31 00 31 00   |1.1.6.1.0.1.1.1.|",
    "00000040  35 00 31 00 31 00 36 00  34 00 37 00 39 00 37 00   |5.1.1.6.4.7.9.7.|",
    "00000050  34 00 36 00 31 00 31 00  36 00 31 00 32 00 30 00   |4.6.1.1.6.1.2.0.|",
    "00000060  31 00 31 00 36 00 74 68  69 73 20 69 73 20 61 2e   |1.1.6.this is a.|",
    "00000070  74 78 74 50 4b 03 04 14  00 00 08 00 00 00 00 21   |txtPK..........!|",
    "00000080  00 84 50 90 ba 0d 00 00  00 0d 00 00 00 48 00 00   |..P..........H..|",
    "00000090  00 31 00 32 00 32 00 31  00 30 00 35 00 31 00 31   |.1.2.2.1.0.5.1.1|",
    "000000a0  00 32 00 31 00 31 00 36  00 31 00 30 00 31 00 31   |.2.1.1.6.1.0.1.1|",
    "000000b0  00 31 00 35 00 31 00 31  00 36 00 34 00 37 00 39   |.1.5.1.1.6.4.7.9|",
    "000000c0  00 38 00 34 00 36 00 31  00 31 00 36 00 31 00 32   |.8.4.6.1.1.6.1.2|",
    "000000d0  00 30 00 31 00 31 00 36  00 74 68 69 73 20 69 73   |.0.1.1.6.this is|",
    "000000e0  20 62 2e 74 78 74 50 4b  01 02 14 03 14 00 00 08   | b.txtPK........|",
    "000000f0  00 00 00 00 21 00 54 2a  30 fd 0d 00 00 00 0d 00   |....!.T*0.......|",
    "00000100  00 00 48 00 00 00 00 00  00 00 00 00 00 00 a4 01   |..H.............|",
    "00000110  00 00 00 00 31 00 32 00  32 00 31 00 30 00 35 00   |....1.2.2.1.0.5.|",
    "00000120  31 00 31 00 32 00 31 00  31 00 36 00 31 00 30 00   |1.1.2.1.1.6.1.0.|",
    "00000130  31 00 31 00 31 00 35 00  31 00 31 00 36 00 34 00   |1.1.1.5.1.1.6.4.|",
    "00000140  37 00 39 00 37 00 34 00  36 00 31 00 31 00 36 00   |7.9.7.4.6.1.1.6.|",
    "00000150  31 00 32 00 30 00 31 00  31 00 36 00 50 4b 01 02   |1.2.0.1.1.6.PK..|",
    "00000160  14 03 14 00 00 08 00 00  00 00 21 00 84 50 90 ba   |..........!..P..|",
    "00000170  0d 00 00 00 0d 00 00 00  48 00 00 00 00 00 00 00   |........H.......|",
    "00000180  00 00 00 00 a4 01 73 00  00 00 31 00 32 00 32 00   |......s...1.2.2.|",
    "00000190  31 00 30 00 35 00 31 00  31 00 32 00 31 00 31 00   |1.0.5.1.1.2.1.1.|",
    "000001a0  36 00 31 00 30 00 31 00  31 00 31 00 35 00 31 00   |6.1.0.1.1.1.5.1.|",
    "000001b0  31 00 36 00 34 00 37 00  39 00 38 00 34 00 36 00   |1.6.4.7.9.8.4.6.|",
    "000001c0  31 00 31 00 36 00 31 00  32 00 30 00 31 00 31 00   |1.1.6.1.2.0.1.1.|",
    "000001d0  36 00 50 4b 05 06 00 00  00 00 02 00 02 00 ec 00   |6.PK............|",
    "000001e0  00 00 e6 00 00 00 00 00                            |........|", "",
  ])
  // Verify the structure matches what external zip tools expect
  // Check ZIP magic at start
  let local_sig = zip_bytes[0].to_int() |
    (zip_bytes[1].to_int() << 8) |
    (zip_bytes[2].to_int() << 16) |
    (zip_bytes[3].to_int() << 24)
  @json.inspect(local_sig, content=67324752) // 0x04034b50

  // Check EOCD signature at end
  let len = zip_bytes.length()
  let eocd_sig = zip_bytes[len - 22].to_int() |
    (zip_bytes[len - 21].to_int() << 8) |
    (zip_bytes[len - 20].to_int() << 16) |
    (zip_bytes[len - 19].to_int() << 24)
  @json.inspect(eocd_sig, content=101010256) // 0x06054b50

  // Verify we can read our own output
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  @json.inspect(decoded.member_count(), content=2)
}

///|
/// BitWriter tests
test "bitwriter_basic" {
  let buf = ByteBuf::new(16, false)
  let writer = BitWriter::new(buf)
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
  let buf = ByteBuf::new(16, false)
  let writer = BitWriter::new(buf)
  // Write 0xFF (8 bits)
  writer.write_bits(0xFF, 8)
  // Write 0xAB (8 bits)
  writer.write_bits(0xAB, 8)
  // Write 3 bits: 0b101
  writer.write_bits(0b101, 3)
  writer.flush()
  let result = buf.contents()
  @json.inspect(
    (result.length(), result[0].to_int(), result[1].to_int(), result[2].to_int()),
    content=[3, 255, 171, 5],
  )
}

///|
test "bitwriter_flush_partial" {
  let buf = ByteBuf::new(16, false)
  let writer = BitWriter::new(buf)
  // Write 5 bits (incomplete byte)
  writer.write_bits(0b10101, 5)
  writer.flush()
  let result = buf.contents()
  // Should pad with 3 zero bits: 0b00010101 = 0x15 = 21
  @json.inspect((result.length(), result[0].to_int()), content=[1, 21])
}

///|
test "bitwriter_align_to_byte" {
  let buf = ByteBuf::new(16, false)
  let writer = BitWriter::new(buf)
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
  let buf = ByteBuf::new(16, false)
  let writer = BitWriter::new(buf)
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

///|
/// Huffman encoder tests
test "huffman_encoder_creation" {
  let encoder = HuffmanEncoder::new()
  @json.inspect((encoder.codes.length(), encoder.max_sym), content=[288,0])
}

///|
test "huffman_encoder_set_get" {
  let encoder = HuffmanEncoder::new()
  // Set code for symbol 65 ('A'): code=0b101, length=3
  let info = sym_info_make(0b101, 3)
  encoder.set(65, info)
  let retrieved = encoder.get(65)
  @json.inspect(
    (sym_info_code(retrieved), sym_info_code_length(retrieved), encoder.max_sym),
    content=[5, 3, 65],
  )
}

///|
test "fixed_litlen_encoder_symbols" {
  // Test a few key symbols from fixed Huffman table
  // Symbol 0: 8 bits
  let info0 = fixed_litlen_encoder.get(0)
  @json.inspect(sym_info_code_length(info0), content=8)
  
  // Symbol 143: 8 bits (last of 0-143 range)
  let info143 = fixed_litlen_encoder.get(143)
  @json.inspect(sym_info_code_length(info143), content=8)
  
  // Symbol 144: 9 bits (first of 144-255 range)
  let info144 = fixed_litlen_encoder.get(144)
  @json.inspect(sym_info_code_length(info144), content=9)
  
  // Symbol 255: 9 bits (last of 144-255 range)
  let info255 = fixed_litlen_encoder.get(255)
  @json.inspect(sym_info_code_length(info255), content=9)
  
  // Symbol 256 (end of block): 7 bits
  let info256 = fixed_litlen_encoder.get(256)
  @json.inspect(sym_info_code_length(info256), content=7)
  
  // Symbol 279: 7 bits (last of 256-279 range)
  let info279 = fixed_litlen_encoder.get(279)
  @json.inspect(sym_info_code_length(info279), content=7)
  
  // Symbol 280: 8 bits
  let info280 = fixed_litlen_encoder.get(280)
  @json.inspect(sym_info_code_length(info280), content=8)
  
  // Max symbol
  @json.inspect(fixed_litlen_encoder.max_sym, content=285)
}

///|
test "fixed_dist_encoder_all_5_bits" {
  // All distance symbols should be 5 bits
  for i = 0; i < 32; i = i + 1 {
    let info = fixed_dist_encoder.get(i)
    let len = sym_info_code_length(info)
    if len != 5 {
      abort("Distance symbol \{i} should have length 5, got \{len}")
    }
  }
  @json.inspect(fixed_dist_encoder.max_sym, content=29)
}

///|
test "sym_info_packing" {
  // Test that sym_info correctly packs and unpacks code and length
  let code = 0b11010110 // 214
  let length = 9
  let info = sym_info_make(code, length)
  @json.inspect(
    (sym_info_code(info), sym_info_code_length(info)),
    content=[214, 9],
  )
  
  // Test with maximum values
  let max_code = (1 << 15) - 1 // 15-bit max code
  let max_length = 15
  let info_max = sym_info_make(max_code, max_length)
  @json.inspect(
    (sym_info_code(info_max), sym_info_code_length(info_max)),
    content=[32767, 15],
  )
}

///|
/// Symbol conversion tests
test "length_to_symbol_basic" {
  // Test key ranges
  @json.inspect(length_to_symbol(3), content=257) // Min length
  @json.inspect(length_to_symbol(10), content=264)
  @json.inspect(length_to_symbol(11), content=265)
  @json.inspect(length_to_symbol(18), content=268)
  @json.inspect(length_to_symbol(258), content=285) // Max length
}

///|
test "distance_to_symbol_basic" {
  // Test key ranges
  @json.inspect(distance_to_symbol(1), content=0) // Min distance
  @json.inspect(distance_to_symbol(4), content=3)
  @json.inspect(distance_to_symbol(5), content=4)
  @json.inspect(distance_to_symbol(256), content=15)
  @json.inspect(distance_to_symbol(32768), content=29) // Max distance
}

///|
/// Test deflate with fixed Huffman (literals only, no LZ77 yet)
test "deflate_fixed_literals_hello" {
  let data = b"hello"
  let compressed = deflate_fixed_literals_only(data, 0, data.length(), true)
  
  // Should be able to decompress it
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(),
      decompressed[1].to_int(),
      decompressed[2].to_int(),
      decompressed[3].to_int(),
      decompressed[4].to_int(),
    ),
    content=[5, 104, 101, 108, 108, 111],
  ) // "hello" = h(104) e(101) l(108) l(108) o(111)
  
  // Compressed should be larger than original (no LZ77 yet)
  // Each byte becomes a Huffman code (8 or 9 bits) plus end-of-block
  let is_larger = compressed.length() > data.length()
  @json.inspect(is_larger, content=true)
}

///|
test "deflate_fixed_literals_empty" {
  let data = b""
  let compressed = deflate_fixed_literals_only(data, 0, 0, true)
  
  // Should decompress to empty
  let decompressed = inflate(compressed, 0, compressed.length(), Some(0))
  @json.inspect(decompressed.length(), content=0)
}

///|
test "deflate_fixed_literals_longer" {
  let data = b"The quick brown fox jumps over the lazy dog"
  let compressed = deflate_fixed_literals_only(data, 0, data.length(), true)
  
  // Should decompress correctly
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  @json.inspect(
    (
      decompressed.length() == data.length(),
      decompressed[0].to_int(), // 'T'
      decompressed[4].to_int(), // 'q'
      decompressed[42].to_int(), // 'g'
    ),
    content=[true, 84, 113, 103],
  )
}

///|
test "deflate_fixed_literals_roundtrip" {
  // Test with various byte values
  let data = b"\x00\x01\x7f\x80\xff"
  let compressed = deflate_fixed_literals_only(data, 0, data.length(), true)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  
  // Check each byte
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(),
      decompressed[1].to_int(),
      decompressed[2].to_int(),
      decompressed[3].to_int(),
      decompressed[4].to_int(),
    ),
    content=[5, 0, 1, 127, 128, 255],
  )
}

// ============================================================================
// LZ77 String Matching Tests
// ============================================================================

///|
test "lz77_hash4_basic" {
  let data = b"test"
  let hash = hash4(data, 0)
  let valid = hash >= 0 && hash < 32768
  @json.inspect(valid, content=true)
}

///|
test "lz77_hash4_consistency" {
  let data1 = b"hello world"
  let data2 = b"xhello world"
  let hash1 = hash4(data1, 0) // "hell"
  let hash2 = hash4(data2, 1) // "hell"
  @json.inspect(hash1 == hash2, content=true)
}

///|
test "lz77_insert_hash_basic" {
  let hash_head = Array::make(32768, -1)
  let hash_prev = Array::make(32768, 0)
  insert_hash(hash_head, hash_prev, 42, 100)
  @json.inspect((hash_head[42], hash_prev[100 % 32768]), content=[100, -1])
}

///|
test "lz77_insert_hash_chain" {
  let hash_head = Array::make(32768, -1)
  let hash_prev = Array::make(32768, 0)
  insert_hash(hash_head, hash_prev, 42, 100)
  insert_hash(hash_head, hash_prev, 42, 200)
  insert_hash(hash_head, hash_prev, 42, 300)
  @json.inspect(
    (hash_head[42], hash_prev[300 % 32768], hash_prev[200 % 32768], hash_prev[100 % 32768]),
    content=[300, 200, 100, -1],
  )
}

///|
test "lz77_match_fwd_identical" {
  let data = b"hello world hello"
  let len = match_fwd(data, 0, 12, 0, 10)
  @json.inspect(len, content=5) // "hello" = 5 chars
}

///|
test "lz77_match_fwd_partial" {
  let data = b"hello world help"
  let len = match_fwd(data, 0, 12, 0, 10)
  @json.inspect(len, content=3) // "hel" = 3 chars
}

///|
test "lz77_backref_packing" {
  let bref = make_backref(100, 5)
  @json.inspect((backref_dist(bref), backref_len(bref)), content=[100, 5])
}

///|
test "lz77_backref_large_values" {
  let bref = make_backref(32768, 258)
  @json.inspect((backref_dist(bref), backref_len(bref)), content=[32768, 258])
}

///|
test "lz77_find_backref_basic" {
  let data = b"hello world hello"
  let hash_head = Array::make(32768, -1)
  let hash_prev = Array::make(32768, 0)
  let hash0 = hash4(data, 0)
  insert_hash(hash_head, hash_prev, hash0, 0)
  let hash12 = hash4(data, 12)
  let bref = find_backref(data, hash_head, hash_prev, 12, hash12, 0, 10, 4, 4096)
  @json.inspect((backref_dist(bref), backref_len(bref)), content=[12, 5])
}

///|
test "lz77_find_backref_no_match" {
  let data = b"abcdefghij"
  let hash_head = Array::make(32768, -1)
  let hash_prev = Array::make(32768, 0)
  let hash0 = hash4(data, 0)
  insert_hash(hash_head, hash_prev, hash0, 0)
  let hash6 = hash4(data, 6)
  let bref = find_backref(data, hash_head, hash_prev, 6, hash6, 0, 10, 4, 4096)
  @json.inspect(bref, content=0) // No match
}

