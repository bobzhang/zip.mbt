// File and Member tests

///|
test "file_stored_simple" {
  let data = b"test data"
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  @json.inspect(
    (
      file.compression is Stored,
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
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  let result = file.to_bytes()
  @json.inspect((result[0].to_int(), result[1].to_int(), result.length()), content=[
    104, 101, 5,
  ])
}

///|
test "file_is_encrypted" {
  let data = b"test"
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  @json.inspect(file.is_encrypted(), content=false)

  // Create a file with encrypted flag set
  let encrypted_file = @file.File::make(
    data,
    0,
    data.length(),
    Stored,
    data.length(),
    0,
    None,
    None,
    Some(@file.gp_flag_encrypted),
  )
  @json.inspect(encrypted_file.is_encrypted(), content=true)
  @json.inspect(encrypted_file.can_extract(), content=false)
}

///|
/// Member tests
test "member_make_file" {
  let data = b"test"
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  let m = @member.make("test.txt", File(file))
  @json.inspect((m.path(), m.is_file(), m.is_dir(), m.mode()), content=[
    "test.txt",
    true,
    false,
    ["FileMode", 420],
  ]) // 0o644 = 420
}

///|
test "member_make_dir" {
  let m = @member.make("mydir", Dir)
  @json.inspect((m.path(), m.is_dir(), m.is_file(), m.mode()), content=[
    "mydir/",
    true,
    false,
    ["FileMode", 493],
  ]) // 0o755 = 493
}

///|
test "member_ensure_unix_path" {
  let data = b"x"
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  let m = @member.make("dir\\file.txt", File(file))
  @json.inspect(m.path(), content="dir/file.txt")
}

///|
test "member_default_mtime" {
  let data = b"x"
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  let m = @member.make("file.txt", File(file))
  @json.inspect(m.mtime(), content=["Ptime", 315532800]) // @types.dos_epoch
}

///|
test "member_custom_mode_and_mtime" {
  let data = b"x"
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  let custom_time = @types.dos_epoch.0 + 1000
  let m = @member.make(
    "file.txt",
    File(file),
    mode=@types.FileMode(0o777),
    mtime=custom_time,
  )
  @json.inspect((m.mode(), m.mtime()), content=[
    ["FileMode", 511],
    ["Ptime", 315533800],
  ]) // 0o777 = 511
}

///|
test "member_format" {
  let data = b"hello"
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  let m = @member.make("test.txt", File(file))
  let formatted = m.format()
  // Should contain key parts: -, permissions, size, path
  @json.inspect(
    (
      formatted.contains("-"),
      formatted.contains("rw-"),
      formatted.contains("test.txt"),
    ),
    content=[true, true, true],
  )
}

///|
test "member_format_long" {
  let data = b"hello world"
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  let m = @member.make("test.txt", File(file))
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
  let m = @member.make("mydir/", Dir)
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
  try {
    let _ = @member.make(long_path, Dir)
    @json.inspect("should have failed", content="error")
  } catch {
    msg => {
      let msg_str = msg.to_string()
      @json.inspect(msg_str.contains("exceeds maximum"), content=true)
    }
  }
}

///|
test "file_make_success" {
  // Test successful file creation with Result
  let data = b"test data"
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  @json.inspect(file.decompressed_size, content=9)
}

///|
/// File accessor tests
test "file_accessors" {
  let data = b"test data"
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  @json.inspect(
    (
      file.compression() is Stored,
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
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  let compressed = file.compressed_bytes_to_bytes()
  @json.inspect(
    (compressed.length(), compressed[0] == data[0], compressed[4] == data[4]),
    content=[5, true, true],
  )
}

///|
/// Test file accessor methods
test "coverage_file_accessors" {
  let data = b"Accessor test"
  let file = @file.File::deflate_of_bytes(data, 0, data.length())
  let _c = file.compressed_bytes()
  let _crc = file.decompressed_crc32()
  let _v = file.version_needed_to_extract()
  @json.inspect(file.can_extract(), content=true)
}

///|
/// Test member with early mtime (before DOS epoch)
test "coverage_member_early_mtime" {
  let early = @types.dos_epoch.0 - 86400 // One day before DOS epoch
  let data = b"X"
  let file = @file.File::deflate_of_bytes(data, 0, data.length())
  let m = @member.make(
    "test.txt",
    File(file),
    mode=@types.FileMode(0o644),
    mtime=early,
  )
  @json.inspect(m.mtime() >= @types.dos_epoch, content=true)
}

///|
/// Test member format_long with empty file
test "coverage_member_empty_format" {
  let data = b""
  let file = @file.File::deflate_of_bytes(data, 0, data.length())
  let m = @member.make("empty.txt", File(file))
  @json.inspect(m.format_long().contains("0%"), content=true)
}
