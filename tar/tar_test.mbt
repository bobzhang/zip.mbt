///|
test "tar_basic" {
  let archive = @tar.TarArchive::empty()
  @json.inspect(archive.length(), content=0)
  let file_entry = @tar.TarEntry::file("test.txt", b"Hello World")
  archive.add(file_entry)
  @json.inspect(archive.length(), content=1)
  let dir_entry = @tar.TarEntry::directory("docs")
  archive.add(dir_entry)
  @json.inspect(archive.length(), content=2)
  let bytes = archive.to_bytes()
  @json.inspect(bytes.length(), content=10240)
}

///|
test "tar_find" {
  let archive = @tar.TarArchive::empty()
  let file_entry = @tar.TarEntry::file("hello.txt", b"Hello TAR")
  archive.add(file_entry)
  match archive.find("hello.txt") {
    Some(found) => {
      @json.inspect(found.name, content="hello.txt")
      @json.inspect(found.size, content=9)
      // Check typeflag by pattern matching instead of inspect
      match found.typeflag {
        @tar.RegularFile => () // Expected
        _ => fail("Expected RegularFile")
      }
    }
    None => fail("File not found")
  }
  match archive.find("missing.txt") {
    Some(_) => fail("Should not find missing file")
    None => () // Expected
  }
}

///|
test "tar_directory" {
  let archive = @tar.TarArchive::empty()
  let dir_entry = @tar.TarEntry::directory("mydir")
  archive.add(dir_entry)
  match archive.find("mydir/") {
    Some(found) => {
      @json.inspect(found.name, content="mydir/")
      @json.inspect(found.size, content=0)
      // Check typeflag by pattern matching instead of inspect
      match found.typeflag {
        @tar.Directory => () // Expected
        _ => fail("Expected Directory")
      }
    }
    None => fail("Directory not found")
  }
}

///|
test "tar_file_properties" {
  let data = b"Test file content"
  let file_entry = @tar.TarEntry::file("readme.txt", data)
  @json.inspect(file_entry.name, content="readme.txt")
  @json.inspect(file_entry.size, content=17)
  @json.inspect(file_entry.mode, content=420) // 0o644 in decimal
  // Compare bytes data directly
  assert_eq(file_entry.data, data)
  match file_entry.typeflag {
    @tar.RegularFile => () // Expected
    _ => fail("Expected RegularFile")
  }
}

///|
test "tar_directory_properties" {
  let dir_entry = @tar.TarEntry::directory("docs/")
  @json.inspect(dir_entry.name, content="docs/")
  @json.inspect(dir_entry.size, content=0)
  @json.inspect(dir_entry.mode, content=493) // 0o755 in decimal
  match dir_entry.typeflag {
    @tar.Directory => () // Expected
    _ => fail("Expected Directory")
  }
}

///|
test "tar_size_calculation" {
  let archive = @tar.TarArchive::empty()

  // Empty archive should be 10240 bytes (20 blocks of 512 bytes each)
  @json.inspect(archive.to_bytes().length(), content=10240)

  // Add a small file (11 bytes)
  let small_file = @tar.TarEntry::file("small.txt", b"Hello World")
  archive.add(small_file)

  // Should still be 10240 bytes:
  // - 1 header block (512 bytes)
  // - 1 data block (512 bytes, padded)
  // - End marker (1024 bytes)
  // - Plus padding to reach minimum 10240
  @json.inspect(archive.to_bytes().length(), content=10240)

  // Add several more files to exceed minimum
  for i = 0; i < 10; i = i + 1 {
    let data = ("Content " + i.to_string()).to_bytes()
    let entry = @tar.TarEntry::file("file" + i.to_string() + ".txt", data)
    archive.add(entry)
  }

  // Now should be larger than 10240
  let size = archive.to_bytes().length()
  @json.inspect(size > 10240, content=true)
  @json.inspect(size % 512, content=0) // Should be multiple of 512
}
