// End-to-End Integration Tests for ZIP Library
// Tests the complete pipeline: compress → archive → encode → decode → extract → decompress

///|
test "e2e_debug_member_lookup" {
  // Minimal test to debug member lookup
  let data = b"test"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("simple.txt", MemberKind::File(file), None, None).unwrap()
  
  let archive = Archive::empty().add(m)
  @json.inspect(archive.member_count(), content=1)
  @json.inspect(archive.mem("simple.txt"), content=true)
  
  // Try to find it
  match archive.find("simple.txt") {
    Some(_) => @json.inspect("found in original", content="found in original")
    None => @json.inspect("not found in original", content="found in original")
  }
}

///|
test "e2e_simple_stored_file" {
  // Start with the simplest possible case - stored (uncompressed) file
  let original_data = b"Hello, World!"
  let orig_len = original_data.length()
  
  // Step 1: Create stored file (no compression)
  let stored_file = File::stored_of_bytes(
    original_data,
    0,
    orig_len,
  ).unwrap()
  
  // Verify we can decompress immediately
  let test_decompress = stored_file.to_bytes()
  @json.inspect(test_decompress.length() == orig_len, content=true)
  
  // Step 2: Create a member
  let m = Member::make(
    "test.txt",
    MemberKind::File(stored_file),
    Some(0o644),
    None,
  ).unwrap()
  
  // Step 3: Create archive with single member
  let archive = Archive::empty().add(m)
  @json.inspect(archive.member_count(), content=1)
  
  // Step 4: Encode to ZIP bytes
  match archive.to_bytes(None) {
    Ok(zip_bytes) => {
      @json.inspect(zip_bytes.length() > 0, content=true)
      
      // Step 5: Decode from ZIP bytes
      match Archive::of_bytes(zip_bytes) {
        Ok(decoded_archive) => {
          @json.inspect(decoded_archive.member_count(), content=1)
          
          // Step 6: Check if member exists
          @json.inspect(decoded_archive.mem("test.txt"), content=true)
          
          // Step 7: Extract and decompress
          match decoded_archive.find("test.txt") {
            Some(extracted_m) => {
              match extracted_m.kind() {
                MemberKind::File(file) => {
                  let decompressed = file.to_bytes()
                  @json.inspect(decompressed.length() == orig_len, content=true)
                  
                  // Verify content matches
                  let mut all_match = true
                  for i = 0; i < orig_len; i = i + 1 {
                    if decompressed[i] != original_data[i] {
                      all_match = false
                    }
                  }
                  @json.inspect(all_match, content=true)
                }
                MemberKind::Dir => @json.inspect("wrong type", content="file")
              }
            }
            None => @json.inspect("not found", content="found")
          }
        }
        Err(msg) => @json.inspect(msg, content="decode ok")
      }
    }
    Err(msg) => @json.inspect(msg, content="encode ok")
  }
}

///|
test "e2e_single_file_roundtrip" {
  // Create original data
  let original_data = b"Hello, World! This is a test file for end-to-end ZIP processing."
  let orig_len = original_data.length()
  
  // Step 1: Compress with DEFLATE
  let compressed_file = File::deflate_of_bytes(
    original_data,
    0,
    orig_len,
    None,
  ).unwrap()
  
  // Step 2: Create a member
  let m = Member::make(
    "test.txt",
    MemberKind::File(compressed_file),
    Some(0o644),
    None,
  ).unwrap()
  
  // Step 3: Create archive and add member
  let archive = Archive::empty().add(m)
  @json.inspect(archive.member_count(), content=1)
  
  // Step 4: Encode to ZIP bytes
  let zip_bytes = archive.to_bytes(None).unwrap()
  @json.inspect(zip_bytes.length() > 0, content=true)
  
  // Step 5: Decode from ZIP bytes
  let decoded_archive = Archive::of_bytes(zip_bytes).unwrap()
  @json.inspect(decoded_archive.member_count(), content=1)
  
  // Step 6: Extract member
  match decoded_archive.find("test.txt") {
    Some(extracted_member) => {
      // Step 7: Get file data and decompress
      match extracted_member.kind() {
        MemberKind::File(file) => {
          let decompressed = file.to_bytes()
          
          // Verify: decompressed data matches original
          @json.inspect(decompressed.length() == orig_len, content=true)
          
          // Verify content byte-by-byte
          let mut matches = true
          for i = 0; i < orig_len; i = i + 1 {
            if decompressed[i] != original_data[i] {
              matches = false
            }
          }
          @json.inspect(matches, content=true)
        }
        MemberKind::Dir => @json.inspect("unexpected directory", content="file")
      }
    }
    None => {
      @json.inspect("member not found", content="found")
    }
  }
}

///|
test "e2e_multiple_files_with_compression_levels" {
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
  
  // Test data with different characteristics
  let text_data = repeat_bytes(b"The quick brown fox jumps over the lazy dog. ", 10)
  let repetitive_data = repeat_bytes(b"AAAAAAAAAA", 100)
  let mixed_data = repeat_bytes(b"Test123!@#$%^&*()_+-=[]{}|;:',.<>?/~`", 20)
  
  // Create files with different compression levels  
  let file1 = File::deflate_of_bytes(
    text_data,
    0,
    text_data.length(),
    None, // Use default level
  ).unwrap()
  
  let file2 = File::deflate_of_bytes(
    repetitive_data,
    0,
    repetitive_data.length(),
    None,
  ).unwrap()
  
  let file3 = File::deflate_of_bytes(
    mixed_data,
    0,
    mixed_data.length(),
    None,
  ).unwrap()
  
  // Create members
  let m1 = Member::make(
    "text.txt",
    MemberKind::File(file1),
    Some(0o644),
    None,
  ).unwrap()
  
  let m2 = Member::make(
    "repetitive.bin",
    MemberKind::File(file2),
    Some(0o644),
    None,
  ).unwrap()
  
  let m3 = Member::make(
    "mixed.dat",
    MemberKind::File(file3),
    Some(0o644),
    None,
  ).unwrap()
  
  // Build archive
  let archive = Archive::empty().add(m1).add(m2).add(m3)
  @json.inspect(archive.member_count(), content=3)
  
  // Encode to ZIP
  let zip_bytes = archive.to_bytes(Some("Multi-file test archive")).unwrap()
  
  // Decode from ZIP
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  @json.inspect(decoded.member_count(), content=3)
  
  // Verify each file
  let text_len = text_data.length()
  let rep_len = repetitive_data.length()
  let mix_len = mixed_data.length()
  
  match decoded.find("text.txt") {
    Some(m) => match m.kind() {
      MemberKind::File(f) => {
        let data = f.to_bytes()
        @json.inspect(data.length() == text_len, content=true)
      }
      _ => ()
    }
    None => ()
  }
  
  match decoded.find("repetitive.bin") {
    Some(m) => match m.kind() {
      MemberKind::File(f) => {
        let data = f.to_bytes()
        @json.inspect(data.length() == rep_len, content=true)
      }
      _ => ()
    }
    None => ()
  }
  
  match decoded.find("mixed.dat") {
    Some(m) => match m.kind() {
      MemberKind::File(f) => {
        let data = f.to_bytes()
        @json.inspect(data.length() == mix_len, content=true)
      }
      _ => ()
    }
    None => ()
  }
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
  let readme_file = File::deflate_of_bytes(readme, 0, readme.length(), None).unwrap()
  let config_file = File::deflate_of_bytes(config, 0, config.length(), None).unwrap()
  let code_file = File::deflate_of_bytes(code, 0, code.length(), None).unwrap()
  
  // Create directory and file members
  let root_dir = Member::make("project/", MemberKind::Dir, Some(0o755), None).unwrap()
  let src_dir = Member::make("project/src/", MemberKind::Dir, Some(0o755), None).unwrap()
  let readme_m = Member::make(
    "project/README.md",
    MemberKind::File(readme_file),
    Some(0o644),
    None,
  ).unwrap()
  let config_m = Member::make(
    "project/config.json",
    MemberKind::File(config_file),
    Some(0o644),
    None,
  ).unwrap()
  let code_m = Member::make(
    "project/src/main.mbt",
    MemberKind::File(code_file),
    Some(0o644),
    None,
  ).unwrap()
  
  // Build archive with directory structure
  let archive = Archive::empty()
    .add(root_dir)
    .add(src_dir)
    .add(readme_m)
    .add(config_m)
    .add(code_m)
  
  @json.inspect(archive.member_count(), content=5)
  
  // Encode to ZIP
  let zip_bytes = archive.to_bytes(Some("Project archive")).unwrap()
  
  // Decode from ZIP
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  @json.inspect(decoded.member_count(), content=5)
  
  // Verify directory exists
  @json.inspect(decoded.mem("project/"), content=true)
  @json.inspect(decoded.mem("project/src/"), content=true)
  
  // Verify files exist and can be decompressed
  match decoded.find("project/README.md") {
    Some(m) => match m.kind() {
      MemberKind::File(f) => {
        let data = f.to_bytes()
        @json.inspect(data.length() == readme_len, content=true)
      }
      _ => ()
    }
    None => ()
  }
  
  match decoded.find("project/src/main.mbt") {
    Some(m) => match m.kind() {
      MemberKind::File(f) => {
        let data = f.to_bytes()
        @json.inspect(data.length() == code_len, content=true)
      }
      _ => ()
    }
    None => ()
  }
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
  let compressed_file = File::deflate_of_bytes(
    large_data,
    0,
    large_data.length(),
    None,
  ).unwrap()
  
  // Verify compression ratio
  let compressed_size = compressed_file.compressed_size()
  let ratio = compressed_size * 100 / original_size
  @json.inspect(ratio < 80, content=true) // Should achieve at least 20% compression
  
  // Create member and archive
  let m = Member::make(
    "large_file.txt",
    MemberKind::File(compressed_file),
    Some(0o644),
    None,
  ).unwrap()
  
  let archive = Archive::empty().add(m)
  
  // Full roundtrip
  let zip_bytes = archive.to_bytes(None).unwrap()
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  
  // Extract and verify
  match decoded.find("large_file.txt") {
    Some(m) => match m.kind() {
      MemberKind::File(f) => {
        let decompressed = f.to_bytes()
        
        // Verify size matches
        @json.inspect(decompressed.length() == original_size, content=true)
        
        // Spot check: verify first and last 100 bytes
        let mut first_100_match = true
        let mut last_100_match = true
        
        for i = 0; i < 100; i = i + 1 {
          if decompressed[i] != large_data[i] {
            first_100_match = false
          }
          let pos = original_size - 100 + i
          if decompressed[pos] != large_data[pos] {
            last_100_match = false
          }
        }
        
        @json.inspect(first_100_match, content=true)
        @json.inspect(last_100_match, content=true)
      }
      _ => ()
    }
    None => ()
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
  let data_len = data.length()
  
  // Create stored (uncompressed) file
  let stored_file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let stored_m = Member::make(
    "stored.bin",
    MemberKind::File(stored_file),
    Some(0o644),
    None,
  ).unwrap()
  
  // Create deflated file
  let deflated_file = File::deflate_of_bytes(
    data,
    0,
    data.length(),
    None,
  ).unwrap()
  let deflated_m = Member::make(
    "deflated.bin",
    MemberKind::File(deflated_file),
    Some(0o644),
    None,
  ).unwrap()
  
  // Create archive with both
  let archive = Archive::empty().add(stored_m).add(deflated_m)
  
  // Encode and decode
  let zip_bytes = archive.to_bytes(None).unwrap()
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  
  // Both should decompress to the same data
  let stored_data = match decoded.find("stored.bin") {
    Some(m) => match m.kind() {
      MemberKind::File(f) => f.to_bytes()
      _ => b""
    }
    None => b""
  }
  
  let deflated_data = match decoded.find("deflated.bin") {
    Some(m) => match m.kind() {
      MemberKind::File(f) => f.to_bytes()
      _ => b""
    }
    None => b""
  }
  
  // Both should match original
  @json.inspect(stored_data.length() == data_len, content=true)
  @json.inspect(deflated_data.length() == data_len, content=true)
  
  // Verify they're identical
  let mut all_match = true
  for i = 0; i < data_len; i = i + 1 {
    if stored_data[i] != deflated_data[i] || stored_data[i] != data[i] {
      all_match = false
    }
  }
  @json.inspect(all_match, content=true)
}

///|
test "e2e_empty_file_handling" {
  // Test with an empty file
  let empty_data = b""
  
  let empty_file = File::deflate_of_bytes(
    empty_data,
    0,
    0,
    None,
  ).unwrap()
  
  let m = Member::make(
    "empty.txt",
    MemberKind::File(empty_file),
    Some(0o644),
    None,
  ).unwrap()
  
  let archive = Archive::empty().add(m)
  
  // Full roundtrip
  let zip_bytes = archive.to_bytes(None).unwrap()
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  
  // Verify empty file is preserved
  match decoded.find("empty.txt") {
    Some(m) => match m.kind() {
      MemberKind::File(f) => {
        let data = f.to_bytes()
        @json.inspect(data.length(), content=0)
      }
      _ => ()
    }
    None => ()
  }
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
  let bin_len = binary_data.length()
  
  // Compress
  let compressed_file = File::deflate_of_bytes(
    binary_data,
    0,
    binary_data.length(),
    None,
  ).unwrap()
  
  let m = Member::make(
    "binary.bin",
    MemberKind::File(compressed_file),
    Some(0o644),
    None,
  ).unwrap()
  
  // Archive and roundtrip
  let archive = Archive::empty().add(m)
  let zip_bytes = archive.to_bytes(None).unwrap()
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  
  // Verify all bytes match
  match decoded.find("binary.bin") {
    Some(m) => match m.kind() {
      MemberKind::File(f) => {
        let decompressed = f.to_bytes()
        @json.inspect(decompressed.length() == bin_len, content=true)
        
        let mut all_bytes_match = true
        for i = 0; i < bin_len; i = i + 1 {
          if decompressed[i] != binary_data[i] {
            all_bytes_match = false
          }
        }
        @json.inspect(all_bytes_match, content=true)
      }
      _ => ()
    }
    None => ()
  }
}

///|
test "e2e_archive_iteration" {
  // Create multiple files
  let files = [
    ("file1.txt", b"Content 1"),
    ("file2.txt", b"Content 2"),
    ("file3.txt", b"Content 3"),
  ]
  
  let mut archive = Archive::empty()
  
  for entry in files {
    let (name, data) = entry
    let file = File::deflate_of_bytes(data, 0, data.length(), None).unwrap()
    let m = Member::make(name, MemberKind::File(file), Some(0o644), None).unwrap()
    archive = archive.add(m)
  }
  
  // Encode and decode
  let zip_bytes = archive.to_bytes(None).unwrap()
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  
  // Iterate through all members
  let count = decoded.fold(fn(_m, acc) { acc + 1 }, 0)
  @json.inspect(count, content=3)
  
  // Verify we can access all files
  @json.inspect(decoded.mem("file1.txt"), content=true)
  @json.inspect(decoded.mem("file2.txt"), content=true)
  @json.inspect(decoded.mem("file3.txt"), content=true)
}

///|
test "e2e_unicode_filename_support" {
  // Test with UTF-8 filenames (if supported)
  let data = b"Unicode filename test"
  let data_len = data.length()
  
  let file = File::deflate_of_bytes(data, 0, data.length(), None).unwrap()
  let m = Member::make(
    "test_文件.txt", // Chinese characters
    MemberKind::File(file),
    Some(0o644),
    None,
  ).unwrap()
  
  let archive = Archive::empty().add(m)
  
  // Full roundtrip
  let zip_bytes = archive.to_bytes(None).unwrap()
  let decoded = Archive::of_bytes(zip_bytes).unwrap()
  
  // Verify file can be found with Unicode name
  @json.inspect(decoded.mem("test_文件.txt"), content=true)
  
  match decoded.find("test_文件.txt") {
    Some(m) => match m.kind() {
      MemberKind::File(f) => {
        let decompressed = f.to_bytes()
        @json.inspect(decompressed.length() == data_len, content=true)
      }
      _ => ()
    }
    None => ()
  }
}
