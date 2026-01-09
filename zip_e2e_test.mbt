// End-to-End Integration Tests for ZIP Library
// Tests the complete pipeline: compress → archive → encode → decode → extract → decompress

///|
test "e2e_debug_member_lookup" {
  // Minimal test to debug member lookup
  let data = b"test"
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  let m = @member.make("simple.txt", File(file))
  let archive = @zip.Archive::empty()
  archive.add(m)
  @json.inspect(archive, content={
    "length": 1,
    "members": [["simple.txt", "File"]],
  })
}

///|
test "e2e_simple_stored_file" {
  // Start with the simplest possible case - stored (uncompressed) file
  let original_data = b"Hello, World!"
  let orig_len = original_data.length()

  // Step 1: Create stored file (no compression)
  let stored_file = @file.File::stored_of_bytes(original_data, 0, orig_len)

  // Verify we can decompress immediately
  let test_decompress = stored_file.to_bytes()
  @json.inspect(test_decompress.length() == orig_len, content=true)

  // Step 2: Create a member
  let m = @member.make(
    "test.txt",
    File(stored_file),
    mode=@types.FileMode(0o644),
  )

  // Step 3: Create archive with single member
  let archive = @zip.Archive::empty()
  archive.add(m)
  @json.inspect(archive, content={
    "length": 1,
    "members": [["test.txt", "File"]],
  })

  // Step 4: Encode to ZIP bytes
  let zip_bytes = archive.to_bytes()

  // Step 5: Decode from ZIP bytes
  let decoded_archive = @zip.Archive::of_bytes(zip_bytes)
  @json.inspect(decoded_archive, content={
    "length": 1,
    "members": [["test.txt", "File"]],
  })

  // Step 7: Extract and decompress
  guard decoded_archive.find("test.txt") is Some(extracted_m) else {
    fail("Member not found")
  }
  guard extracted_m.kind() is File(file) else { fail("Expected file kind") }
  let decompressed = file.to_bytes()
  assert_eq(decompressed, original_data)
}

///|
test "e2e_single_file_roundtrip" {
  // Create original data
  let original_data = b"Hello, World! This is a test file for end-to-end ZIP processing."
  let orig_len = original_data.length()

  // Step 1: Compress with DEFLATE
  let compressed_file = @file.File::deflate_of_bytes(original_data, 0, orig_len)

  // Step 2: Create a member
  let m = @member.make(
    "test.txt",
    File(compressed_file),
    mode=@types.FileMode(0o644),
  )

  // Step 3: Create archive and add member
  let archive = @zip.Archive::empty()
  archive.add(m)
  @json.inspect(archive, content={
    "length": 1,
    "members": [["test.txt", "File"]],
  })

  // Step 4: Encode to ZIP bytes
  let zip_bytes = archive.to_bytes()

  // Step 5: Decode from ZIP bytes
  let decoded_archive = @zip.Archive::of_bytes(zip_bytes)
  @json.inspect(decoded_archive, content={
    "length": 1,
    "members": [["test.txt", "File"]],
  })

  // Step 6: Extract member and verify
  guard decoded_archive.find("test.txt") is Some(extracted_member) else {
    fail("Member not found")
  }
  guard extracted_member.kind() is File(file) else {
    fail("Expected file kind")
  }
  let decompressed = file.to_bytes()
  assert_eq(decompressed, original_data)
}

///|
test "e2e_multiple_files_with_compression_levels" {

  // Test data with different characteristics
  let text_data = b"The quick brown fox jumps over the lazy dog. ".repeat(10)
  let repetitive_data = b"AAAAAAAAAA".repeat(100)
  let mixed_data = b"Test123!@#$%^&*()_+-=[]{}|;:',.<>?/~`".repeat(20)

  // Create files with different compression levels  
  let file1 = @file.File::deflate_of_bytes(text_data, 0, text_data.length())
  let file2 = @file.File::deflate_of_bytes(
    repetitive_data,
    0,
    repetitive_data.length(),
  )
  let file3 = @file.File::deflate_of_bytes(mixed_data, 0, mixed_data.length())

  // Create members
  let m1 = @member.make("text.txt", File(file1), mode=@types.FileMode(0o644))
  let m2 = @member.make(
    "repetitive.bin",
    File(file2),
    mode=@types.FileMode(0o644),
  )
  let m3 = @member.make("mixed.dat", File(file3), mode=@types.FileMode(0o644))

  // Build archive
  let archive = @zip.Archive::empty()
  archive.add(m1)
  archive.add(m2)
  archive.add(m3)
  @json.inspect(archive, content={
    "length": 3,
    "members": [
      ["text.txt", "File"],
      ["repetitive.bin", "File"], // insertion order
      ["mixed.dat", "File"],
    ],
  })

  // Encode to ZIP
  let zip_bytes = archive.to_bytes(
    first=@fpath.Fpath("Multi-file test archive"),
  )

  // Decode from ZIP
  let decoded = @zip.Archive::of_bytes(zip_bytes)
  @json.inspect(decoded, content={
    "length": 3,
    "members": [
      ["text.txt", "File"],
      ["repetitive.bin", "File"],
      ["mixed.dat", "File"],
    ],
  })

  // Verify each file can be decompressed to original size
  guard decoded.find("text.txt") is Some(m1) else { fail("text.txt not found") }
  guard m1.kind() is File(f1) else { fail("Expected file") }
  assert_eq(f1.to_bytes().length(), text_data.length())
  guard decoded.find("repetitive.bin") is Some(m2) else {
    fail("repetitive.bin not found")
  }
  guard m2.kind() is File(f2) else { fail("Expected file") }
  assert_eq(f2.to_bytes().length(), repetitive_data.length())
  guard decoded.find("mixed.dat") is Some(m3) else {
    fail("mixed.dat not found")
  }
  guard m3.kind() is File(f3) else { fail("Expected file") }
  assert_eq(f3.to_bytes().length(), mixed_data.length())
}

///|
test "e2e_directory_structure_with_files" {
  // Create a directory structure with nested files
  let readme = b"# Project README\n\nThis is a test project.\n"
  let config = b"{ \"version\": \"1.0\", \"name\": \"test\" }"
  let code = b"fn main() {\n  println(\"Hello, World!\")\n}\n"
  let readme_len = readme.length()
  let code_len = code.length()

  // Compress files
  let readme_file = @file.File::deflate_of_bytes(readme, 0, readme.length())
  let config_file = @file.File::deflate_of_bytes(config, 0, config.length())
  let code_file = @file.File::deflate_of_bytes(code, 0, code.length())

  // Create directory and file members
  let root_dir = @member.make("project/", Dir, mode=@types.FileMode(0o755))
  let src_dir = @member.make("project/src/", Dir, mode=@types.FileMode(0o755))
  let readme_m = @member.make(
    "project/README.md",
    File(readme_file),
    mode=@types.FileMode(0o644),
  )
  let config_m = @member.make(
    "project/config.json",
    File(config_file),
    mode=@types.FileMode(0o644),
  )
  let code_m = @member.make(
    "project/src/main.mbt",
    File(code_file),
    mode=@types.FileMode(0o644),
  )

  // Build archive with directory structure
  let archive = @zip.Archive::empty()
  archive.add(root_dir)
  archive.add(src_dir)
  archive.add(readme_m)
  archive.add(config_m)
  archive.add(code_m)
  @json.inspect(archive, content={
    "length": 5,
    "members": [
      ["project/", "Dir"],
      ["project/src/", "Dir"],
      ["project/README.md", "File"],
      ["project/config.json", "File"],
      ["project/src/main.mbt", "File"],
    ],
  })

  // Encode to ZIP
  let zip_bytes = archive.to_bytes(first=@fpath.Fpath("Project archive"))

  // Decode from ZIP
  let decoded = @zip.Archive::of_bytes(zip_bytes)
  @json.inspect(decoded, content={
    "length": 5,
    "members": [
      ["project/", "Dir"],
      ["project/src/", "Dir"],
      ["project/README.md", "File"],
      ["project/config.json", "File"],
      ["project/src/main.mbt", "File"],
    ],
  })

  // Verify files can be decompressed to original size
  guard decoded.find("project/README.md") is Some(m1) else {
    fail("README not found")
  }
  guard m1.kind() is File(f1) else { fail("Expected file") }
  assert_eq(f1.to_bytes().length(), readme_len)
  guard decoded.find("project/src/main.mbt") is Some(m2) else {
    fail("main.mbt not found")
  }
  guard m2.kind() is File(f2) else { fail("Expected file") }
  assert_eq(f2.to_bytes().length(), code_len)
}

///|
test "e2e_large_file_compression" {
  // Create a large file with mixed content (10KB+)
  let large_data_array : Array[Byte] = []

  // Pattern: repetitive text with some variation
  let base_text = b"The quick brown fox jumps over the lazy dog. 0123456789 "
  for i = 0; i < 200; i = i + 1 {
    for j = 0; j < base_text.length(); j = j + 1 {
      large_data_array.push(base_text[j])
    }
    // Add variation every 10 iterations
    if i % 10 == 0 {
      // Simple variation without string interpolation
      let var_bytes = b"VARIATION_"
      for k = 0; k < var_bytes.length(); k = k + 1 {
        large_data_array.push(var_bytes[k])
      }
    }
  }
  let large_data = Bytes::from_array(large_data_array)
  let original_size = large_data.length()
  @json.inspect(original_size > 10000, content=true)

  // Compress with default level
  let compressed_file = @file.File::deflate_of_bytes(
    large_data,
    0,
    large_data.length(),
  )

  // Verify compression ratio
  let compressed_size = compressed_file.compressed_size()
  let ratio = compressed_size * 100 / original_size
  @json.inspect(ratio < 80, content=true) // Should achieve at least 20% compression

  // Create member and archive
  let m = @member.make(
    "large_file.txt",
    File(compressed_file),
    mode=@types.FileMode(0o644),
  )
  let archive = @zip.Archive::empty()
  archive.add(m)

  // Full roundtrip
  let zip_bytes = archive.to_bytes()
  let decoded = @zip.Archive::of_bytes(zip_bytes)

  // Extract and verify
  guard decoded.find("large_file.txt") is Some(m) else {
    fail("Member not found")
  }
  guard m.kind() is File(f) else { fail("Expected file") }
  let decompressed = f.to_bytes()
  assert_eq(decompressed.length(), original_size)

  // Spot check: verify first and last 100 bytes
  for i = 0; i < 100; i = i + 1 {
    assert_eq(decompressed[i], large_data[i])
    let pos = original_size - 100 + i
    assert_eq(decompressed[pos], large_data[pos])
  }
}

///|
test "e2e_stored_vs_deflate_comparison" {
  // Helper function to repeat bytes
  fn repeat_bytes(data : Bytes, times : Int) -> Bytes {
    let arr : Array[Byte] = []
    for j = 0; j < times; j = j + 1 {
      for i = 0; i < data.length(); i = i + 1 {
        arr.push(data[i])
      }
    }
    Bytes::from_array(arr)
  }

  // Test data that compresses well
  let data = repeat_bytes(b"AAAAAAAAAA", 100)

  // Create stored (uncompressed) file
  let stored_file = @file.File::stored_of_bytes(data, 0, data.length())
  let stored_m = @member.make(
    "stored.bin",
    File(stored_file),
    mode=@types.FileMode(0o644),
  )

  // Create deflated file
  let deflated_file = @file.File::deflate_of_bytes(data, 0, data.length())
  let deflated_m = @member.make(
    "deflated.bin",
    File(deflated_file),
    mode=@types.FileMode(0o644),
  )

  // Create archive with both
  let archive = @zip.Archive::empty()
  archive.add(stored_m)
  archive.add(deflated_m)

  // Encode and decode
  let zip_bytes = archive.to_bytes()
  let decoded = @zip.Archive::of_bytes(zip_bytes)

  // Both should decompress to the same data
  guard decoded.find("stored.bin") is Some(m1) else {
    fail("stored.bin not found")
  }
  guard m1.kind() is File(f1) else { fail("Expected file") }
  let stored_data = f1.to_bytes()
  guard decoded.find("deflated.bin") is Some(m2) else {
    fail("deflated.bin not found")
  }
  guard m2.kind() is File(f2) else { fail("Expected file") }
  let deflated_data = f2.to_bytes()

  // Verify all three match
  assert_eq(stored_data, data)
  assert_eq(deflated_data, data)
  assert_eq(stored_data, deflated_data)
}

///|
test "e2e_empty_file_handling" {
  // Test with an empty file
  let empty_data = b""
  let empty_file = @file.File::deflate_of_bytes(empty_data, 0, 0)
  let m = @member.make(
    "empty.txt",
    File(empty_file),
    mode=@types.FileMode(0o644),
  )
  let archive = @zip.Archive::empty()
  archive.add(m)

  // Full roundtrip
  let zip_bytes = archive.to_bytes()
  let decoded = @zip.Archive::of_bytes(zip_bytes)

  // Verify empty file is preserved
  guard decoded.find("empty.txt") is Some(m) else { fail("Member not found") }
  guard m.kind() is File(f) else { fail("Expected file") }
  let data = f.to_bytes()
  assert_eq(data.length(), 0)
}

///|
test "e2e_binary_data_roundtrip" {
  // Test with binary data containing all byte values
  let binary_array : Array[Byte] = []

  // Include all byte values 0-255
  for i = 0; i < 256; i = i + 1 {
    binary_array.push(i.to_byte())
  }

  // Repeat pattern
  for j = 0; j < 10; j = j + 1 {
    for i = 0; i < 256; i = i + 1 {
      binary_array.push(i.to_byte())
    }
  }
  let binary_data = Bytes::from_array(binary_array)

  // Compress
  let compressed_file = @file.File::deflate_of_bytes(
    binary_data,
    0,
    binary_data.length(),
  )
  let m = @member.make(
    "binary.bin",
    File(compressed_file),
    mode=@types.FileMode(0o644),
  )

  // Archive and roundtrip
  let archive = @zip.Archive::empty()
  archive.add(m)
  let zip_bytes = archive.to_bytes()
  let decoded = @zip.Archive::of_bytes(zip_bytes)

  // Verify all bytes match
  guard decoded.find("binary.bin") is Some(m) else { fail("Member not found") }
  guard m.kind() is File(f) else { fail("Expected file") }
  let decompressed = f.to_bytes()
  assert_eq(decompressed, binary_data)
}

///|
test "e2e_archive_iteration" {
  // Create multiple files
  let files = [
    ("file1.txt", b"Content 1"),
    ("file2.txt", b"Content 2"),
    ("file3.txt", b"Content 3"),
  ]
  let archive = @zip.Archive::empty()
  for entry in files {
    let (name, data) = entry
    let file = @file.File::deflate_of_bytes(data, 0, data.length())
    let m = @member.make(name, File(file), mode=@types.FileMode(0o644))
    archive.add(m)
  }

  // Encode and decode
  let zip_bytes = archive.to_bytes()
  let decoded = @zip.Archive::of_bytes(zip_bytes)

  // Verify structure
  @json.inspect(decoded, content={
    "length": 3,
    "members": [
      ["file1.txt", "File"],
      ["file2.txt", "File"],
      ["file3.txt", "File"],
    ],
  })
}

///|
test "e2e_unicode_filename_support" {
  // Test with UTF-8 filenames (if supported)
  let data = b"Unicode filename test"
  let data_len = data.length()
  let file = @file.File::deflate_of_bytes(data, 0, data.length())
  let m = @member.make(
    "test_文件.txt", // Chinese characters
    File(file),
    mode=@types.FileMode(0o644),
  )
  let archive = @zip.Archive::empty()
  archive.add(m)

  // Full roundtrip
  let zip_bytes = archive.to_bytes()
  let decoded = @zip.Archive::of_bytes(zip_bytes)

  // Verify file can be found with Unicode name
  guard decoded.find("test_文件.txt") is Some(m) else {
    fail("Unicode member not found")
  }
  guard m.kind() is File(f) else { fail("Expected file") }
  let decompressed = f.to_bytes()
  assert_eq(decompressed.length(), data_len)
}

// Additional e2e tests from zip_test.mbt

///|
test "e2e_simple_stored_zip" {
  // Create a simple ZIP with one stored file
  // This should produce a deterministic output we can verify
  let content = b"Hello, World!"
  let file = @file.File::stored_of_bytes(content, 0, content.length())

  // Use a specific timestamp for deterministic output
  let fixed_time = @types.dos_epoch // 1980-01-01 00:00:00
  let m = @member.make(
    "hello.txt",
    File(file),
    mode=@types.FileMode(0o644),
    mtime=fixed_time,
  )
  let archive = @zip.Archive::empty()
  archive.add(m)
  let zip_bytes = archive.to_bytes()

  // Verify we can read it back
  let decoded = @zip.Archive::of_bytes(zip_bytes)
  @json.inspect(decoded, content={
    "length": 1,
    "members": [["hello.txt", "File"]],
  })

  // Verify content matches
  guard decoded.find("hello.txt") is Some(found) else {
    fail("Member not found")
  }
  guard found.kind() is File(f) else { fail("Expected file") }
  let extracted = f.to_bytes()
  assert_eq(extracted, content)
}

///|
test "e2e_zip_structure_verification" {
  // Create a ZIP and verify its structure matches ZIP spec
  let content = b"test"
  let file = @file.File::stored_of_bytes(content, 0, content.length())
  let m = @member.make("test.txt", File(file))
  let archive = @zip.Archive::empty()
  archive.add(m)
  let zip_bytes = archive.to_bytes()

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
  let file1 = @file.File::stored_of_bytes(b"File 1", 0, 6)
  let file2 = @file.File::stored_of_bytes(b"File 2", 0, 6)
  let file3 = @file.File::stored_of_bytes(b"File 3", 0, 6)
  let m1 = @member.make(
    "a.txt",
    File(file1),
    mode=@types.FileMode(0o644),
    mtime=@types.dos_epoch,
  )
  let m2 = @member.make(
    "b.txt",
    File(file2),
    mode=@types.FileMode(0o644),
    mtime=@types.dos_epoch,
  )
  let m3 = @member.make(
    "c.txt",
    File(file3),
    mode=@types.FileMode(0o644),
    mtime=@types.dos_epoch,
  )
  let archive = @zip.Archive::empty()
  archive.add(m1)
  archive.add(m2)
  archive.add(m3)
  let zip_bytes = archive.to_bytes()

  // Verify roundtrip
  let decoded = @zip.Archive::of_bytes(zip_bytes)
  @json.inspect(decoded, content={
    "length": 3,
    "members": [["a.txt", "File"], ["b.txt", "File"], ["c.txt", "File"]],
  })

  // Verify all files are present and correct
  guard decoded.find("a.txt") is Some(found) else { fail("a.txt not found") }
  guard found.kind() is File(f) else { fail("Expected file") }
  let data = f.to_bytes()
  assert_eq(data, b"File 1")
}

///|
test "e2e_deflate_compatibility" {
  // Test deflate compression creates valid streams
  let original = b"AAAAAAAAAA" // Highly compressible (RLE pattern)
  let file = @file.File::deflate_of_bytes(original, 0, original.length())

  // Verify it's marked as deflate
  @json.inspect(file.compression() is Deflate, content=true)

  // Verify decompression works
  let decompressed = file.to_bytes()
  @json.inspect(decompressed == original, content=true)

  // Verify in a ZIP archive
  let m = @member.make("data.bin", File(file))
  let archive = @zip.Archive::empty()
  archive.add(m)
  let zip_bytes = archive.to_bytes()

  // Read back and verify
  let decoded = @zip.Archive::of_bytes(zip_bytes)
  guard decoded.find("data.bin") is Some(found) else {
    fail("Member not found")
  }
  guard found.kind() is File(f) else { fail("Expected file") }
  let data = f.to_bytes()
  assert_eq(data, original)
}

///|
test "e2e_empty_archive_exact_format" {
  // Empty archive should be exactly 22 bytes (EOCD only)
  let archive = @zip.Archive::empty()
  let zip_bytes = archive.to_bytes()
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
  let dir = @member.make(
    "docs/",
    Dir,
    mode=@types.FileMode(0o755),
    mtime=@types.dos_epoch,
  )
  let file_data = b"readme content"
  let file = @file.File::stored_of_bytes(file_data, 0, file_data.length())
  let f = @member.make(
    "docs/README.md",
    File(file),
    mode=@types.FileMode(0o644),
    mtime=@types.dos_epoch,
  )
  let archive = @zip.Archive::empty()
  archive.add(dir)
  archive.add(f)
  let zip_bytes = archive.to_bytes()

  // Verify structure
  let decoded = @zip.Archive::of_bytes(zip_bytes)
  @json.inspect(decoded, content={
    "length": 2,
    "members": [["docs/", "Dir"], ["docs/README.md", "File"]],
  })

  // Verify directory
  guard decoded.find("docs/") is Some(d) else { fail("Directory not found") }
  assert_true(d.is_dir())

  // Verify file
  guard decoded.find("docs/README.md") is Some(found) else {
    fail("should find docs/README.md")
  }
  guard found.kind() is File(f) else { fail("docs/README.md should be a file") }
  let data = f.to_bytes()
  @json.inspect(data == file_data, content=true)
}

///|
test "e2e_metadata_preservation" {
  // Test that metadata (mode, mtime) is preserved through encode/decode
  let content = b"test"
  let file = @file.File::stored_of_bytes(content, 0, content.length())
  let custom_mode = 0o755
  let custom_time = @types.dos_epoch.0 + 86400 // One day after DOS epoch
  let m = @member.make(
    "executable.sh",
    File(file),
    mode=custom_mode,
    mtime=custom_time,
  )
  let archive = @zip.Archive::empty()
  archive.add(m)
  let zip_bytes = archive.to_bytes()
  let decoded = @zip.Archive::of_bytes(zip_bytes)
  guard decoded.find("executable.sh") is Some(found) else {
    fail("should find executable.sh")
  }
  // Mode and mtime should be preserved
  @json.inspect((found.mode(), found.mtime()), content=[
    ["FileMode", 493],
    ["Ptime", 315619200],
  ])
}

///|
/// Real ZIP file tests - using external zip tool created file
test "e2e_read_real_zip_file" {
  // Read the zip file created by external zip tool
  // This tests compatibility with real ZIP files
  let zip_data = Bytes::from_array([
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
    // CRC-32 (0xFD302A54 = 4248086100)
     0x54, 0x2A, 0x30, 0xFD,
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
    // CRC-32 (0xBA905084 = 3130945668)
     0x84, 0x50, 0x90, 0xBA,
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
     0x54, 0x2A, 0x30, 0xFD,
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
     0x84, 0x50, 0x90, 0xBA,
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
    // Relative offset of local header (56 bytes = 0x38)
     0x38, 0x00, 0x00, 0x00,
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
    // Size of the central directory (118 bytes = 0x76 for both entries)
     0x76, 0x00, 0x00, 0x00,
    // Offset of start of central directory with respect to the starting disk number (112 bytes = 0x70)
     0x70, 0x00, 0x00, 0x00,
    // ZIP file comment length
     0x00, 0x00,
  ])
  let archive = @zip.Archive::of_bytes(zip_data)
  // Verify archive structure
  @json.inspect(archive.member_count(), content=2)

  // Verify first file
  guard archive.find("ziptest/a.txt") is Some(m) else {
    fail("should find ziptest/a.txt")
  }
  guard m.kind() is File(file) else { fail("ziptest/a.txt should be a file") }
  let content = file.to_bytes()
  @json.inspect(content == b"this is a.txt", content=true)

  // Verify second file
  guard archive.find("ziptest/b.txt") is Some(m) else {
    fail("should find ziptest/b.txt")
  }
  guard m.kind() is File(file) else { fail("ziptest/b.txt should be a file") }
  let content = file.to_bytes()
  @json.inspect(content == b"this is b.txt", content=true)
}

///|
test "e2e_create_and_read_ziptest_equivalent" {
  // Create the same archive using MoonBit and verify it matches
  let file1 = @file.File::stored_of_bytes(b"this is a.txt", 0, 13)
  let file2 = @file.File::stored_of_bytes(b"this is b.txt", 0, 13)
  let member1 = @member.make("ziptest/a.txt", File(file1))
  let member2 = @member.make("ziptest/b.txt", File(file2))
  let archive = @zip.Archive::empty()
  archive.add(member1)
  archive.add(member2)
  let zip_bytes = archive.to_bytes()

  // Verify it has ZIP magic
  // @json.inspect(bytes_has_zip_magic(zip_bytes), content=true)

  // Read it back and verify contents
  let decoded = @zip.Archive::of_bytes(zip_bytes)
  @json.inspect(decoded.member_count(), content=2)

  // Verify both files exist and have correct content
  guard decoded.find("ziptest/a.txt") is Some(m) else {
    fail("should find ziptest/a.txt")
  }
  guard m.kind() is File(file) else { fail("ziptest/a.txt should be a file") }
  let content = file.to_bytes()
  @json.inspect(content == b"this is a.txt", content=true)
  guard decoded.find("ziptest/b.txt") is Some(m) else {
    fail("should find ziptest/b.txt")
  }
  guard m.kind() is File(file) else { fail("ziptest/b.txt should be a file") }
  let content = file.to_bytes()
  @json.inspect(content == b"this is b.txt", content=true)
}

///|
test "e2e_ziptest_roundtrip_compatibility" {
  // Test that we can create a zip file and external tools can read it
  let file1 = @file.File::stored_of_bytes(b"this is a.txt", 0, 13)
  let file2 = @file.File::stored_of_bytes(b"this is b.txt", 0, 13)
  let member1 = @member.make("ziptest/a.txt", File(file1))
  let member2 = @member.make("ziptest/b.txt", File(file2))
  let archive = @zip.Archive::empty()
  archive.add(member1)
  archive.add(member2)
  let zip_bytes = archive.to_bytes()
  // FIXME:(upstream) use mulitple line instead
  @json.inspect(@hexdump.hex_dump(zip_bytes).split("\n").to_array(), content=[
    "00000000  50 4b 03 04 14 00 00 08  00 00 00 00 21 00 54 2a   |PK..........!.T*|",
    "00000010  30 fd 0d 00 00 00 0d 00  00 00 0d 00 00 00 7a 69   |0.............zi|",
    "00000020  70 74 65 73 74 2f 61 2e  74 78 74 74 68 69 73 20   |ptest/a.txtthis |",
    "00000030  69 73 20 61 2e 74 78 74  50 4b 03 04 14 00 00 08   |is a.txtPK......|",
    "00000040  00 00 00 00 21 00 84 50  90 ba 0d 00 00 00 0d 00   |....!..P........|",
    "00000050  00 00 0d 00 00 00 7a 69  70 74 65 73 74 2f 62 2e   |......ziptest/b.|",
    "00000060  74 78 74 74 68 69 73 20  69 73 20 62 2e 74 78 74   |txtthis is b.txt|",
    "00000070  50 4b 01 02 14 03 14 00  00 08 00 00 00 00 21 00   |PK............!.|",
    "00000080  54 2a 30 fd 0d 00 00 00  0d 00 00 00 0d 00 00 00   |T*0.............|",
    "00000090  00 00 00 00 00 00 00 00  a4 01 00 00 00 00 7a 69   |..............zi|",
    "000000a0  70 74 65 73 74 2f 61 2e  74 78 74 50 4b 01 02 14   |ptest/a.txtPK...|",
    "000000b0  03 14 00 00 08 00 00 00  00 21 00 84 50 90 ba 0d   |.........!..P...|",
    "000000c0  00 00 00 0d 00 00 00 0d  00 00 00 00 00 00 00 00   |................|",
    "000000d0  00 00 00 a4 01 38 00 00  00 7a 69 70 74 65 73 74   |.....8...ziptest|",
    "000000e0  2f 62 2e 74 78 74 50 4b  05 06 00 00 00 00 02 00   |/b.txtPK........|",
    "000000f0  02 00 76 00 00 00 70 00  00 00 00 00               |..v...p.....|",
    "",
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
  let decoded = @zip.Archive::of_bytes(zip_bytes)
  @json.inspect(decoded.member_count(), content=2)
}
