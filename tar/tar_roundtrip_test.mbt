/// Round-trip tests for TAR implementation
/// Test that we can create TAR → serialize → parse → verify

///|
test "tar_roundtrip_simple" {
  // Create original archive
  let original = @tar.TarArchive::empty()
  let file_data = b"Hello TAR world!"
  let file_entry = @tar.TarEntry::file("test.txt", file_data)
  original.add(file_entry)

  // Serialize to bytes
  let tar_bytes = original.to_bytes()
  @json.inspect(tar_bytes.length() >= 10240, content=true)

  // Parse back from bytes
  let parsed = @tar.TarArchive::of_bytes(tar_bytes)
  @json.inspect(parsed.length(), content=1)

  // Verify the parsed entry
  guard parsed.find("test.txt") is Some(found) else {
    fail("File not found in parsed archive")
  }
  @json.inspect(found.name, content="test.txt")
  @json.inspect(found.size, content=16)
  assert_eq(found.data, file_data)
  match found.typeflag {
    @tar.RegularFile => () // Expected
    _ => fail("Expected RegularFile")
  }
}

///|
test "tar_roundtrip_multiple_files" {
  let original = @tar.TarArchive::empty()

  // Add multiple files
  let file1 = @tar.TarEntry::file("readme.txt", b"This is a README")
  let file2 = @tar.TarEntry::file("data.bin", b"\x00\x01\x02\x03\x04")
  let dir1 = @tar.TarEntry::directory("docs/")
  let file3 = @tar.TarEntry::file(
    "docs/guide.md", b"# User Guide\n\nContent here.",
  )
  original.add(file1)
  original.add(file2)
  original.add(dir1)
  original.add(file3)
  @json.inspect(original.length(), content=4)

  // Round-trip
  let tar_bytes = original.to_bytes()
  let parsed = @tar.TarArchive::of_bytes(tar_bytes)
  @json.inspect(parsed.length(), content=4)

  // Check each entry
  guard parsed.find("readme.txt") is Some(f1) else {
    fail("readme.txt not found")
  }
  assert_eq(f1.data, b"This is a README")
  @json.inspect(f1.size, content=16)
  guard parsed.find("data.bin") is Some(f2) else { fail("data.bin not found") }
  assert_eq(f2.data, b"\x00\x01\x02\x03\x04")
  @json.inspect(f2.size, content=5)
  guard parsed.find("docs/") is Some(d1) else {
    fail("docs/ directory not found")
  }
  @json.inspect(d1.size, content=0)
  match d1.typeflag {
    @tar.Directory => () // Expected
    _ => fail("Expected Directory")
  }
  guard parsed.find("docs/guide.md") is Some(f3) else {
    fail("docs/guide.md not found")
  }
  assert_eq(f3.data, b"# User Guide\n\nContent here.")
  @json.inspect(f3.size, content=27)
}

///|
test "tar_roundtrip_empty_archive" {
  let original = @tar.TarArchive::empty()
  let tar_bytes = original.to_bytes()
  @json.inspect(tar_bytes.length(), content=10240) // Standard empty size
  let parsed = @tar.TarArchive::of_bytes(tar_bytes)
  @json.inspect(parsed.length(), content=0)
}

///|
test "tar_roundtrip_large_file" {
  let original = @tar.TarArchive::empty()

  // Create a large file that spans multiple 512-byte blocks
  let large_data = b"X".repeat(4000)
  let large_file = @tar.TarEntry::file("large.dat", large_data)
  original.add(large_file)
  let tar_bytes = original.to_bytes()
  let parsed = @tar.TarArchive::of_bytes(tar_bytes)
  @json.inspect(parsed.length(), content=1)
  guard parsed.find("large.dat") is Some(found) else {
    fail("Large file not found")
  }
  @json.inspect(found.size, content=4000)
  assert_eq(found.data, large_data)
}

///|
test "tar_roundtrip_preserve_metadata" {
  let original = @tar.TarArchive::empty()

  // Create entry with specific metadata using default constructor 
  // then verify metadata is preserved through round-trip
  let file_data = b"test content"
  let entry = @tar.TarEntry::file("test.txt", file_data)
  original.add(entry)
  let tar_bytes = original.to_bytes()
  let parsed = @tar.TarArchive::of_bytes(tar_bytes)
  guard parsed.find("test.txt") is Some(found) else { fail("File not found") }

  // Verify basic metadata is preserved
  @json.inspect(found.name, content="test.txt")
  @json.inspect(found.size, content=12)
  @json.inspect(found.mode, content=420) // 0o644 in decimal (default)
  assert_eq(found.data, file_data)
}
