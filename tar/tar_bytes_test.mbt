/// Tests for TAR implementation focusing on raw bytes vs UTF-16 string handling
/// and header field correctness.

///|
test "tar_bytes_vs_string_handling" {
  // Test that we handle raw bytes correctly in TAR format
  let archive = @tar.TarArchive::empty()

  // Create file with non-ASCII / binary bytes to test proper handling
  // Use actual byte escapes (single backslash) so size = 18
  let binary_data = b"\x00\x01\x02Hello\xFF\xFE World\x03\x04"
  // Actual length is 18 bytes (previous test expected 14)
  let file_entry = @tar.TarEntry::file("binary.dat", binary_data)
  archive.add(file_entry)

  // Create file with Unicode content (encoded as UTF-8 in TAR)
  let unicode_data = @encoding/utf8.encode("Hello 世界 🌍")
  let unicode_file = @tar.TarEntry::file("unicode.txt", unicode_data)
  archive.add(unicode_file)

  // Round-trip
  let tar_bytes = archive.to_bytes()
  let parsed = @tar.TarArchive::of_bytes(tar_bytes)
  @json.inspect(parsed.length(), content=2)

  // Verify binary data preservation
  guard parsed.find("binary.dat") is Some(found_binary) else {
    fail("Binary file not found")
  }
  assert_eq(found_binary.data, binary_data)
  @json.inspect(found_binary.size, content=18)

  // Verify Unicode data preservation
  guard parsed.find("unicode.txt") is Some(found_unicode) else {
    fail("Unicode file not found")
  }
  assert_eq(found_unicode.data, unicode_data)
  // UTF-8 encoding of "Hello 世界 🌍" should be > 10 bytes
  @json.inspect(found_unicode.size > 10, content=true)
}

///|
test "tar_header_field_encoding" {
  // Test that TAR header fields are properly encoded as ASCII/UTF-8 bytes
  let archive = @tar.TarArchive::empty()

  // ASCII filename
  let ascii_file = @tar.TarEntry::file("test-file_123.txt", b"content")
  archive.add(ascii_file)

  // Directory entry (must end with slash)
  let dir_entry = @tar.TarEntry::directory("some-dir/")
  archive.add(dir_entry)
  let tar_bytes = archive.to_bytes()
  let parsed = @tar.TarArchive::of_bytes(tar_bytes)
  @json.inspect(parsed.length(), content=2)
  guard parsed.find("test-file_123.txt") is Some(found_file) else {
    fail("ASCII file not found")
  }
  @json.inspect(found_file.name, content="test-file_123.txt")
  guard parsed.find("some-dir/") is Some(found_dir) else {
    fail("Directory not found")
  }
  @json.inspect(found_dir.name, content="some-dir/")
  match found_dir.typeflag {
    @tar.Directory => ()
    _ => fail("Expected Directory type")
  }
}

///|
test "tar_octal_field_parsing" {
  // Use builder API instead of raw record to avoid invalid record construction
  let archive = @tar.TarArchive::empty()
  let entry = @tar.TarEntry::file("test.txt", b"hello")
  // entry has default mode/uid/gid/mtime (0) so we just check size & data
  archive.add(entry)
  let tar_bytes = archive.to_bytes()
  let parsed = @tar.TarArchive::of_bytes(tar_bytes)
  guard parsed.find("test.txt") is Some(found) else { fail("File not found") }
  @json.inspect(found.size, content=5)
  assert_eq(found.data, b"hello")
}

///|
test "tar_format_structure_verification" {
  // Verify TAR format follows proper structure & block alignment
  let archive = @tar.TarArchive::empty()
  let small_file = @tar.TarEntry::file("small.txt", b"Hi")
  // Encode as UTF-8 to ensure 1 byte per character (avoid UTF-16 doubling)
  let medium_data = b"x".repeat(600)
  let large_data = b"y".repeat(1500)
  let medium_file = @tar.TarEntry::file("medium.txt", medium_data)
  let large_file = @tar.TarEntry::file("large.txt", large_data)
  archive.add(small_file)
  archive.add(medium_file)
  archive.add(large_file)
  let tar_bytes = archive.to_bytes()
  @json.inspect(tar_bytes.length() % 512, content=0)
  @json.inspect(tar_bytes.length() >= 10240, content=true)
  let parsed = @tar.TarArchive::of_bytes(tar_bytes)
  @json.inspect(parsed.length(), content=3)
  guard parsed.find("small.txt") is Some(f1) else {
    fail("small.txt not found")
  }
  assert_eq(f1.data, b"Hi")
  guard parsed.find("medium.txt") is Some(f2) else {
    fail("medium.txt not found")
  }
  @json.inspect(f2.size, content=600)
  guard parsed.find("large.txt") is Some(f3) else {
    fail("large.txt not found")
  }
  @json.inspect(f3.size, content=1500)
}
