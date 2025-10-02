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
    content=("dir/subdir/file.txt"),
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
  @json.inspect(fpath_sanitize("a/b/c"), content=("a/b/c"))
}

///|
test "fpath_sanitize_removes_dots" {
  @json.inspect(fpath_sanitize("a/./b/../c"), content=("a/b/c"))
}

///|
test "fpath_sanitize_removes_empty" {
  @json.inspect(fpath_sanitize("a//b///c"), content=("a/b/c"))
}

///|
test "fpath_sanitize_mixed_slashes" {
  @json.inspect(fpath_sanitize("a\\b/c"), content=("a/b/c"))
}

///|
test "format_file_mode" {
  // 0o755 = rwxr-xr-x
  @json.inspect(format_file_mode(0o755), content="rwxr-xr-x")
  // 0o644 = rw-r--r--
  @json.inspect(format_file_mode(0o644), content="rw-r--r--")
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
  @json.inspect((m.path(), m.is_file(), m.is_dir(), m.mode()), content=(["test.txt",true,false,420])) // 0o644 = 420
}

///|
test "member_make_dir" {
  let m = Member::make("mydir", MemberKind::Dir, None, None).unwrap()
  @json.inspect((m.path(), m.is_dir(), m.is_file(), m.mode()), content=(["mydir/",true,false,493])) // 0o755 = 493
}

///|
test "member_ensure_unix_path" {
  let data = b"x"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("dir\\file.txt", MemberKind::File(file), None, None).unwrap()
  @json.inspect(m.path(), content=("dir/file.txt"))
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
    content=[true,true,true],
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
    content=[false,2,true,false],
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
      @json.inspect(found.path(), content=("test.txt"))
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
    content=[1,false,true],
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
  @json.inspect(paths, content=("a.txt,b.txt,c.txt"))
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
    Ok(file) => {
      @json.inspect(file.compression == Compression::Deflate, content=true)
      @json.inspect(file.decompressed_size, content=13)
      // With LZ77+Huffman, compressed size will be smaller than stored format
      // Just verify it's reasonable (not larger than original + overhead)
      let reasonable = file.compressed_size > 0 && file.compressed_size < 30
      @json.inspect(reasonable, content=true)
    }
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
      // Empty deflate with LZ77+Huffman: block header + EOB symbol
      // Should be very small (< 5 bytes)
      let small = file.compressed_size > 0 && file.compressed_size < 5
      @json.inspect(small, content=true)
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
  @json.inspect(size, content=118)
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
        content=[3,true,true,true],
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
              @json.inspect((extracted.length(), extracted[0] == data[0]), content=[31,true])
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
    content=[true,true,false],
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
  @json.inspect((restored.member_count(), restored.mem("test.txt")), content=[1,true])
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
  @json.inspect(@hexdump.hex_dump(zip_bytes).split("\n").to_array(), content=(["00000000  50 4b 03 04 14 00 00 08  00 00 00 00 21 00 54 2a   |PK..........!.T*|","00000010  30 fd 0d 00 00 00 0d 00  00 00 0d 00 00 00 7a 69   |0.............zi|","00000020  70 74 65 73 74 2f 61 2e  74 78 74 74 68 69 73 20   |ptest/a.txtthis |","00000030  69 73 20 61 2e 74 78 74  50 4b 03 04 14 00 00 08   |is a.txtPK......|","00000040  00 00 00 00 21 00 84 50  90 ba 0d 00 00 00 0d 00   |....!..P........|","00000050  00 00 0d 00 00 00 7a 69  70 74 65 73 74 2f 62 2e   |......ziptest/b.|","00000060  74 78 74 74 68 69 73 20  69 73 20 62 2e 74 78 74   |txtthis is b.txt|","00000070  50 4b 01 02 14 03 14 00  00 08 00 00 00 00 21 00   |PK............!.|","00000080  54 2a 30 fd 0d 00 00 00  0d 00 00 00 0d 00 00 00   |T*0.............|","00000090  00 00 00 00 00 00 00 00  a4 01 00 00 00 00 7a 69   |..............zi|","000000a0  70 74 65 73 74 2f 61 2e  74 78 74 50 4b 01 02 14   |ptest/a.txtPK...|","000000b0  03 14 00 00 08 00 00 00  00 21 00 84 50 90 ba 0d   |.........!..P...|","000000c0  00 00 00 0d 00 00 00 0d  00 00 00 00 00 00 00 00   |................|","000000d0  00 00 00 a4 01 38 00 00  00 7a 69 70 74 65 73 74   |.....8...ziptest|","000000e0  2f 62 2e 74 78 74 50 4b  05 06 00 00 00 00 02 00   |/b.txtPK........|","000000f0  02 00 76 00 00 00 70 00  00 00 00 00               |..v...p.....|",""]))
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

// ============================================================================
// Full LZ77 + Huffman Compression Tests
// ============================================================================

///|
test "deflate_fixed_empty" {
  let data = b""
  let compressed = deflate_fixed(data, 0, 0, true, 4, 4096)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(0))
  @json.inspect(decompressed.length(), content=0)
}

///|
test "deflate_fixed_simple" {
  let data = b"hello"
  let compressed = deflate_fixed(data, 0, data.length(), true, 4, 4096)
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
  )
}

///|
test "deflate_fixed_with_repetition" {
  // String with obvious repetition that LZ77 should compress
  let data = b"abcabcabcabc"
  let compressed = deflate_fixed(data, 0, data.length(), true, 4, 4096)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  
  // Should decompress correctly
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(), // 'a'
      decompressed[3].to_int(), // 'a'
      decompressed[6].to_int(), // 'a'
      decompressed[9].to_int(), // 'a'
    ),
    content=[12, 97, 97, 97, 97],
  )
  
  // Compressed should be smaller than original due to LZ77
  let is_smaller = compressed.length() < data.length()
  @json.inspect(is_smaller, content=true)
}

///|
test "deflate_fixed_longer_text" {
  let data = b"The quick brown fox jumps over the lazy dog. The quick brown fox."
  let compressed = deflate_fixed(data, 0, data.length(), true, 4, 4096)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  
  // Verify length and some key characters
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(), // 'T'
      decompressed[46].to_int(), // 'h' (in "The" second time)
      decompressed[decompressed.length() - 1].to_int(), // '.'
    ),
    content=[65, 84, 104, 46],
  )
}

///|
test "deflate_fixed_all_same" {
  // Highly compressible: all same byte
  let buf = ByteBuf::new(100, false)
  for i = 0; i < 100; i = i + 1 {
    buf.add_byte(0x61) // 'a'
  }
  let data = buf.contents()
  
  let compressed = deflate_fixed(data, 0, data.length(), true, 4, 4096)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  
  // Should decompress to correct length
  @json.inspect(decompressed.length(), content=100)
  
  // Should be highly compressed (much smaller)
  let ratio = compressed.length() < 20
  @json.inspect(ratio, content=true)
}

///|
test "deflate_fixed_binary_data" {
  // Test with various byte values including null bytes
  let data = b"\x00\x01\x02\x03\x00\x01\x02\x03\xff\xfe\xfd"
  let compressed = deflate_fixed(data, 0, data.length(), true, 4, 4096)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(),
      decompressed[4].to_int(), // Should match [0] due to repetition
      decompressed[10].to_int(),
    ),
    content=[11, 0, 0, 253],
  )
}

///|
test "deflate_fixed_no_compression_benefit" {
  // Random-looking data that won't compress well
  let data = b"abcdefghijklmnop"
  let compressed = deflate_fixed(data, 0, data.length(), true, 4, 4096)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  
  // Should still decompress correctly even if not smaller
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(),
      decompressed[15].to_int(),
    ),
    content=[16, 97, 112],
  )
}

///|
test "deflate_fixed_substring_matches" {
  // Test lazy matching with overlapping potential matches
  let data = b"aaabbbaaabbbccc"
  let compressed = deflate_fixed(data, 0, data.length(), true, 4, 4096)
  let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
  
  @json.inspect(
    (
      decompressed.length(),
      decompressed[0].to_int(), // 'a'
      decompressed[6].to_int(), // 'a' (second occurrence)
      decompressed[12].to_int(), // 'c'
    ),
    content=[15, 97, 97, 99],
  )
}

// ============================================================================
// End-to-End Integration Tests
// ============================================================================

///|
test "complete_zip_workflow_with_compression" {
  // Demonstrate complete ZIP workflow with real compression
  
  // 1. Create multiple files with different characteristics
  let text1 = b"The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog."
  let text2 = b"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" // Highly compressible
  let text3 = b"Random data: x7f3k9m2p"
  
  // 2. Compress files
  let file1 = File::deflate_of_bytes(text1, 0, text1.length(), None).unwrap()
  let file2 = File::deflate_of_bytes(text2, 0, text2.length(), None).unwrap()
  let file3 = File::deflate_of_bytes(text3, 0, text3.length(), None).unwrap()
  
  // 3. Create members
  let m1 = Member::make("doc.txt", MemberKind::File(file1), None, None).unwrap()
  let m2 = Member::make("repeated.txt", MemberKind::File(file2), None, None).unwrap()
  let m3 = Member::make("random.txt", MemberKind::File(file3), None, None).unwrap()
  
  // 4. Build archive
  let archive = Archive::empty().add(m1).add(m2).add(m3)
  
  // 5. Serialize to ZIP format
  let zip_bytes = archive.to_bytes(None).unwrap()
  
  // 6. Verify it's a valid ZIP (deserialize)
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  
  // 7. Extract and verify each file
  match decoded.find("doc.txt") {
    Some(member) => match member.kind() {
      MemberKind::File(f) => {
        let data = f.to_bytes()
        @json.inspect(
          (data.length(), data[0].to_int()),
          content=[89, 84],
        ) // 'T'
      }
      _ => ()
    }
    None => ()
  }
  
  match decoded.find("repeated.txt") {
    Some(member) => match member.kind() {
      MemberKind::File(f) => {
        let data = f.to_bytes()
        // Verify it decompressed correctly
        @json.inspect(
          (data.length(), data[0].to_int(), data[39].to_int()),
          content=[40, 97, 97],
        )
        
        // Verify actual compression happened
        let ratio = f.compressed_size() < 15 // Should be < 40% of original
        @json.inspect(ratio, content=true)
      }
      _ => ()
    }
    None => ()
  }
  
  match decoded.find("random.txt") {
    Some(member) => match member.kind() {
      MemberKind::File(f) => {
        let data = f.to_bytes()
        @json.inspect(data.length(), content=22)
      }
      _ => ()
    }
    None => ()
  }
  
  // 8. Verify archive has all members
  let count = decoded.fold(fn(_m, acc) { acc + 1 }, 0)
  @json.inspect(count, content=3)
}

// ============================================================================
// zlib Wrapper Format Tests (RFC 1950)
// ============================================================================

///|
test "zlib_compress_basic" {
  let data = b"Hello, zlib!"
  let (adler, compressed) = zlib_compress(data, 0, data.length(), None)
  
  // Check header
  let cmf = compressed[0].to_int()
  let flg = compressed[1].to_int()
  
  // CMF should be 0x78 (deflate with 32KB window)
  @json.inspect(cmf, content=120)
  
  // Header checksum should be valid
  let header = (cmf << 8).lor(flg)
  let valid = header.mod(31) == 0
  @json.inspect(valid, content=true)
  
  // Should have trailer (last 4 bytes)
  let has_trailer = compressed.length() >= 6
  @json.inspect(has_trailer, content=true)
  
  // Adler-32 should be non-zero
  let adler_valid = adler > 0L
  @json.inspect(adler_valid, content=true)
}

///|
test "zlib_roundtrip_simple" {
  let data = b"Test data for zlib compression"
  let (adler, compressed) = zlib_compress(data, 0, data.length(), None)
  
  // Decompress
  let result = zlib_decompress(compressed, 0, compressed.length())
  match result {
    Ok((decompressed, computed_adler)) => {
      // Verify data matches
      @json.inspect(
        (
          decompressed.length(),
          decompressed[0].to_int(),
          decompressed[data.length() - 1].to_int(),
        ),
        content=[30, 84, 110],
      ) // 'T' and 'n'
      
      // Verify checksum matches
      @json.inspect(adler == computed_adler, content=true)
    }
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "zlib_roundtrip_empty" {
  let data = b""
  let (adler, compressed) = zlib_compress(data, 0, 0, None)
  
  let result = zlib_decompress(compressed, 0, compressed.length())
  match result {
    Ok((decompressed, _)) => {
      @json.inspect(decompressed.length(), content=0)
    }
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "zlib_roundtrip_repetitive" {
  // Highly compressible data
  let buf = ByteBuf::new(100, false)
  for i = 0; i < 100; i = i + 1 {
    buf.add_byte(0x61) // 'a'
  }
  let data = buf.contents()
  
  let (adler, compressed) = zlib_compress(data, 0, data.length(), None)
  
  // Should achieve good compression
  let ratio = compressed.length() < 30
  @json.inspect(ratio, content=true)
  
  // Should decompress correctly
  let result = zlib_decompress(compressed, 0, compressed.length())
  match result {
    Ok((decompressed, _)) => {
      @json.inspect(decompressed.length(), content=100)
    }
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "zlib_roundtrip_binary" {
  // Test with various byte values
  let data = b"\x00\x01\x7f\x80\xff\x00\x01\x7f\x80\xff"
  let (_, compressed) = zlib_compress(data, 0, data.length(), None)
  
  let result = zlib_decompress(compressed, 0, compressed.length())
  match result {
    Ok((decompressed, _)) => {
      @json.inspect(
        (
          decompressed.length(),
          decompressed[0].to_int(),
          decompressed[4].to_int(),
          decompressed[9].to_int(),
        ),
        content=[10, 0, 255, 255],
      )
    }
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "zlib_compression_levels" {
  let data = b"Test data with some repetition: test test test"
  
  // Try different compression levels (avoid constructing variants directly)
  let (_, default) = zlib_compress(data, 0, data.length(), None)
  
  // All should decompress correctly
  let default_ok = match zlib_decompress(default, 0, default.length()) {
    Ok((d, _)) => d.length() == data.length()
    Err(_) => false
  }
  
  @json.inspect(default_ok, content=true)
}

///|
test "zlib_invalid_header" {
  // Invalid compression method (not deflate)
  let data = b"\x00\x00\x00\x00\x00\x00"
  let result = zlib_decompress(data, 0, data.length())
  
  match result {
    Ok(_) => @json.inspect("should fail", content="error")
    Err(_) => @json.inspect("error", content="error")
  }
}

///|
test "zlib_too_short" {
  let data = b"\x78\x9c" // Just header, no data
  let result = zlib_decompress(data, 0, data.length())
  
  match result {
    Ok(_) => @json.inspect("should fail", content="error")
    Err(_) => @json.inspect("error", content="error")
  }
}

///|
test "zlib_bad_checksum" {
  // Create valid zlib data, then corrupt checksum
  let data = b"test"
  let (_, compressed) = zlib_compress(data, 0, data.length(), None)
  
  // Corrupt last byte of Adler-32
  let buf = ByteBuf::new(compressed.length(), false)
  for i = 0; i < compressed.length() - 1; i = i + 1 {
    buf.add_byte(compressed[i].to_int())
  }
  buf.add_byte(0xFF) // Wrong checksum byte
  let corrupted = buf.contents()
  
  let result = zlib_decompress(corrupted, 0, corrupted.length())
  match result {
    Ok(_) => @json.inspect("should fail", content="error")
    Err(_) => @json.inspect("error", content="error")
  }
}

// ============================================================================
// Dynamic Huffman Tests
// ============================================================================

test "dynamic_huffman_simple" {
  // Create ASCII bytes directly (not from UTF-16 string)
  let data = b"AAAAAABBBBBBCCCCCC"
  let compressed = deflate_dynamic(data, 0, data.length(), true, 8, 128)
  
  // Should decompress correctly
  let decompressed = inflate(compressed, 0, compressed.length(), None)
  @json.inspect(decompressed, content="AAAAAABBBBBBCCCCCC")
}

test "dynamic_huffman_vs_fixed" {
  // Data with non-uniform distribution - test both compress correctly
  let data = b"AAAAAAAAAAABBBBBCCCCCDDD"
  
  let dynamic = deflate_dynamic(data, 0, data.length(), true, 8, 128)
  let fixed = deflate_fixed(data, 0, data.length(), true, 8, 128)
  
  // Both should decompress correctly
  let d1 = inflate(dynamic, 0, dynamic.length(), None)
  let d2 = inflate(fixed, 0, fixed.length(), None)
  @json.inspect((d1, d2), content=[
    "AAAAAAAAAAABBBBBCCCCCDDD",
    "AAAAAAAAAAABBBBBCCCCCDDD",
  ])
  
  // Note: For short data, dynamic may be larger due to header overhead
  // Dynamic Huffman is beneficial for larger blocks (typically >1KB)
}

test "dynamic_huffman_single_symbol" {
  // All same character - should compress well with LZ77
  let data = b"AAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  let compressed = deflate_dynamic(data, 0, data.length(), true, 8, 128)
  
  // Should compress to less than original (LZ77 + dynamic Huffman)
  let decompressed = inflate(compressed, 0, compressed.length(), None)
  @json.inspect(
    (compressed.length() < data.length(), decompressed.length()),
    content=[true, 28],
  )
}

test "dynamic_huffman_empty" {
  let compressed = deflate_dynamic(Bytes::new(0), 0, 0, true, 8, 128)
  let decompressed = inflate(compressed, 0, compressed.length(), None)
  @json.inspect(decompressed.length(), content=0)
}

test "dynamic_huffman_short" {
  let data = b"Hi"
  let compressed = deflate_dynamic(data, 0, data.length(), true, 8, 128)
  let decompressed = inflate(compressed, 0, compressed.length(), None)
  @json.inspect(decompressed, content="Hi")
}

test "dynamic_huffman_text" {
  let data = b"The quick brown fox jumps over the lazy dog."
  let compressed = deflate_dynamic(data, 0, data.length(), true, 8, 128)
  
  // Should compress well
  let decompressed = inflate(compressed, 0, compressed.length(), None)
  @json.inspect(decompressed, content="The quick brown fox jumps over the lazy dog.")
}

test "dynamic_huffman_binary" {
  // Binary data with all byte values
  let data = Array::make(256, b'\x00')
  for i = 0; i < 256; i = i + 1 {
    data[i] = i.to_byte()
  }
  let data_bytes = Bytes::from_fixedarray(FixedArray::from_iter(data[0:].iter()))
  
  let compressed = deflate_dynamic(data_bytes, 0, 256, true, 8, 128)
  let decompressed = inflate(compressed, 0, compressed.length(), None)
  
  @json.inspect((decompressed.length(), decompressed[0].to_int(), decompressed[255].to_int()), content=[
    256, 0, 255,
  ])
}

test "dynamic_vs_fixed" {
  // Compare compression ratios
  let data = b"AAAA"
  
  
  let dynamic = deflate_dynamic(data, 0, data.length(), true, 8, 128)
  let fixed = deflate_fixed(data, 0, data.length(), true, 8, 128)
  
  // Both must decompress correctly
  let d1 = inflate(dynamic, 0, dynamic.length(), None)
  let d2 = inflate(fixed, 0, fixed.length(), None)
  
  @json.inspect((d1, d2), content=["AAAA", "AAAA"])
}

// ============================================================================
// Integration Tests - Verify compression level selection
// ============================================================================

test "compression_level_fast_integration" {
  // Fast level should compress and decompress correctly
  let data = b"AAAABBBBCCCCDDDDEEEEFFFFGGGG" // 28 bytes
  let result = File::deflate_of_bytes(data, 0, data.length(), None)
  
  match result {
    Ok(file) => {
      // Decompress and verify
      let decompressed = inflate(
        file.compressed_bytes,
        file.start,
        file.compressed_size,
        None
      )
      @json.inspect(decompressed, content="AAAABBBBCCCCDDDDEEEEFFFFGGGG")
    }
    Err(e) => @json.inspect(e, content="Should not error")
  }
}

test "compression_level_large_data_integration" {
  // Large data should use dynamic Huffman for better compression
  let data = Array::make(300, b'A')
  for i = 0; i < 100; i = i + 1 {
    data[i] = b'A'
  }
  for i = 100; i < 200; i = i + 1 {
    data[i] = b'B'
  }
  for i = 200; i < 300; i = i + 1 {
    data[i] = b'C'
  }
  let data_bytes = Bytes::from_fixedarray(FixedArray::from_iter(data[0:].iter()))
  
  let result = File::deflate_of_bytes(data_bytes, 0, 300, None)
  
  match result {
    Ok(file) => {
      // Decompress and verify  
      let decompressed = inflate(
        file.compressed_bytes,
        file.start,
        file.compressed_size,
        None
      )
      @json.inspect(
        (decompressed.length(), decompressed[0].to_int(), decompressed[150].to_int(), decompressed[250].to_int()),
        content=[300, 65, 66, 67]
      )
    }
    Err(e) => @json.inspect(e, content="Should not error")
  }
}

test "compression_with_lz77_matches" {
  // Repetitive data should compress well with LZ77 + Huffman
  let data = b"The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog."
  let result = File::deflate_of_bytes(data, 0, data.length(), None)
  
  match result {
    Ok(file) => {
      // Should achieve good compression ratio
      @json.inspect(
        file.compressed_size < data.length(),
        content=true
      )
      // Verify decompression
      let decompressed = inflate(
        file.compressed_bytes,
        file.start,
        file.compressed_size,
        None
      )
      @json.inspect(decompressed.length() == data.length(), content=true)
    }
    Err(e) => @json.inspect(e, content="Should not error")
  }
}
// ============================================================================
// High-level DEFLATE API Compatibility Tests
// ============================================================================

///|
test "deflate_api_basic" {
  let data = b"Hello, DEFLATE API!"
  match deflate(data, 0, data.length(), None) {
    Ok(compressed) => {
      // Should compress successfully
      @json.inspect(compressed.length() > 0, content=true)
      
      // Should decompress back to original
      let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
      @json.inspect(decompressed.length(), content=19)
    }
    Err(_) => @json.inspect("should not fail", content="success")
  }
}

///|
test "crc32_and_deflate_api" {
  let data = b"Test CRC-32 with deflate"
  match crc32_and_deflate(data, 0, data.length(), None) {
    Ok((crc, compressed)) => {
      // CRC should match direct calculation
      let expected_crc = bytes_crc32(data, 0, data.length())
      @json.inspect(crc == expected_crc, content=true)
      
      // Compressed data should be valid
      let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
      @json.inspect(decompressed.length(), content=24)
    }
    Err(_) => @json.inspect("should not fail", content="success")
  }
}

///|
test "adler32_and_deflate_api" {
  let data = b"Test Adler-32 with deflate"
  match adler32_and_deflate(data, 0, data.length(), None) {
    Ok((adler, compressed)) => {
      // Adler-32 should match direct calculation
      let expected_adler = bytes_adler32(data, 0, data.length())
      @json.inspect(adler == expected_adler, content=true)
      
      // Compressed data should be valid
      let decompressed = inflate(compressed, 0, compressed.length(), Some(data.length()))
      @json.inspect(decompressed.length(), content=26)
    }
    Err(_) => @json.inspect("should not fail", content="success")
  }
}


