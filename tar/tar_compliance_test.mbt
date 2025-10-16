///|
/// Test TAR implementation compatibility
test "tar_comprehensive_test" {
  let archive = @tar.TarArchive::empty()

  // Add a text file
  let file1 = @tar.TarEntry::file("hello.txt", b"Hello from MoonBit TAR!")
  archive.add(file1)

  // Add a directory
  let dir1 = @tar.TarEntry::directory("docs/")
  archive.add(dir1)

  // Add another file in the directory
  let file2 = @tar.TarEntry::file(
    "docs/readme.md", b"# MoonBit TAR\n\nThis is a test file.",
  )
  archive.add(file2)
  let tar_bytes = archive.to_bytes()

  // Verify basic structure
  @json.inspect(archive.length(), content=3)
  @json.inspect(tar_bytes.length() >= 10240, content=true)
  @json.inspect(tar_bytes.length() % 512, content=0)

  // Test finding entries
  guard archive.find("hello.txt") is Some(found) else {
    fail("hello.txt not found")
  }
  @json.inspect(found.size, content=23)
  guard archive.find("docs/") is Some(found_dir) else {
    fail("docs/ not found")
  }
  @json.inspect(found_dir.size, content=0)
  guard archive.find("docs/readme.md") is Some(found_file) else {
    fail("docs/readme.md not found")
  }
  @json.inspect(found_file.size, content=35)
}

///|
test "tar_format_compliance" {
  // Test that our implementation follows TAR format rules
  let archive = @tar.TarArchive::empty()

  // Test 1: Empty archive size
  let empty_size = archive.to_bytes().length()
  @json.inspect(empty_size, content=10240) // Standard minimum

  // Test 2: Single file archive
  let small_file = @tar.TarEntry::file("test.txt", b"test")
  archive.add(small_file)
  let single_file_size = archive.to_bytes().length()
  @json.inspect(single_file_size, content=10240) // Still minimum for this size

  // Test 3: Large file that exceeds minimum
  let large_data = b"x".repeat(8000) // Much larger to exceed 10240 minimum
  let large_file = @tar.TarEntry::file("large.txt", large_data)
  archive.add(large_file)
  let large_archive_size = archive.to_bytes().length()
  @json.inspect(large_archive_size > 10240, content=true)
  @json.inspect(large_archive_size % 512, content=0)

  // Verify structure: 2 files = 2 headers (1024) + data blocks + end marker (1024) + padding
  // large.txt needs 8000 bytes = 16 blocks (8192 bytes)
  // test.txt needs 4 bytes = 1 block (512 bytes)
  // Total: 1024 (headers) + 8704 (data) + 1024 (end) = 10752 minimum
  let expected_min = 10752
  @json.inspect(large_archive_size >= expected_min, content=true)
}
