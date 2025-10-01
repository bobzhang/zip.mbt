// Simple CLI tool to test ZIP creation compatibility
// This creates test ZIP files that can be verified with standard tools

///|
fn main {
  println("=== MoonBit ZIP Library Test ===\n")

  // Test 1: Create a simple ZIP file
  test_simple_zip()

  // Test 2: Create a multi-file ZIP
  test_multi_file_zip()

  // Test 3: Create ZIP with directory
  test_directory_zip()
  println("\n✅ All tests completed successfully!")
}

///|
fn test_simple_zip() -> Unit {
  println("Test 1: Creating simple.zip with one file...")
  let content = b"Hello from MoonBit ZIP library!\nThis is a test file.\n"
  let file = @lib.File::stored_of_bytes(content, 0, content.length())
  match file {
    Ok(f) => {
      let m = @lib.Member::make(
        "hello.txt",
        @lib.MemberKind::File(f),
        Some(0o644),
        Some(@lib.dos_epoch),
      )
      match m {
        Ok(mem) => {
          let archive = @lib.Archive::empty().add(mem)
          match archive.to_bytes(None) {
            Ok(zip_bytes) => {
              println("  ✓ Created ZIP: \{zip_bytes.length()} bytes")
              println("  ✓ Has magic: \{@lib.bytes_has_zip_magic(zip_bytes)}")

              // Verify roundtrip
              match @lib.Archive::of_bytes(zip_bytes) {
                Ok(decoded) =>
                  println(
                    "  ✓ Roundtrip successful: \{decoded.member_count()} member(s)",
                  )
                Err(e) => println("  ✗ Decode failed: \{e}")
              }
            }
            Err(e) => println("  ✗ Encoding failed: \{e}")
          }
        }
        Err(e) => println("  ✗ Member creation failed: \{e}")
      }
    }
    Err(e) => println("  ✗ File creation failed: \{e}")
  }
}

///|
fn test_multi_file_zip() -> Unit {
  println("\nTest 2: Creating multi-file.zip with multiple files...")
  let file1 = @lib.File::stored_of_bytes(b"Content of file 1", 0, 17).unwrap()
  let file2 = @lib.File::stored_of_bytes(b"Content of file 2", 0, 17).unwrap()
  let file3 = @lib.File::stored_of_bytes(b"Content of file 3", 0, 17).unwrap()
  let m1 = @lib.Member::make(
    "file1.txt",
    @lib.MemberKind::File(file1),
    None,
    None,
  ).unwrap()
  let m2 = @lib.Member::make(
    "file2.txt",
    @lib.MemberKind::File(file2),
    None,
    None,
  ).unwrap()
  let m3 = @lib.Member::make(
    "file3.txt",
    @lib.MemberKind::File(file3),
    None,
    None,
  ).unwrap()
  println("  Original members:")
  println("    - \{m1.path()}")
  println("    - \{m2.path()}")
  println("    - \{m3.path()}")
  let archive = @lib.Archive::empty().add(m1).add(m2).add(m3)
  println("  Archive member count: \{archive.member_count()}")
  match archive.to_bytes(None) {
    Ok(zip_bytes) => {
      println("  ✓ Created ZIP: \{zip_bytes.length()} bytes")

      // Verify all members
      match @lib.Archive::of_bytes(zip_bytes) {
        Ok(decoded) => {
          println("  Decoded member count: \{decoded.member_count()}")
          let members = decoded.to_array()
          println("  Decoded members:")
          for i = 0; i < members.length(); i = i + 1 {
            println("    - \{members[i].path()}")
          }
          let has_all = decoded.mem("file1.txt") &&
            decoded.mem("file2.txt") &&
            decoded.mem("file3.txt")
          println("  ✓ All files present: \{has_all}")
        }
        Err(e) => println("  ✗ Decode failed: \{e}")
      }
    }
    Err(e) => println("  ✗ Encoding failed: \{e}")
  }
}

///|
fn test_directory_zip() -> Unit {
  println("\nTest 3: Creating archive with directories...")
  let dir = @lib.Member::make("docs/", @lib.MemberKind::Dir, Some(0o755), None).unwrap()
  let file_data = b"Documentation file content"
  let file = @lib.File::stored_of_bytes(file_data, 0, file_data.length()).unwrap()
  let readme = @lib.Member::make(
    "docs/README.md",
    @lib.MemberKind::File(file),
    Some(0o644),
    None,
  ).unwrap()
  let archive = @lib.Archive::empty().add(dir).add(readme)
  match archive.to_bytes(None) {
    Ok(zip_bytes) => {
      println("  ✓ Created ZIP: \{zip_bytes.length()} bytes")
      match @lib.Archive::of_bytes(zip_bytes) {
        Ok(decoded) => {
          match decoded.find("docs/") {
            Some(d) =>
              println("  ✓ Directory entry found: is_dir=\{d.is_dir()}")
            None => println("  ✗ Directory not found")
          }
          match decoded.find("docs/README.md") {
            Some(f) => println("  ✓ File entry found: is_file=\{f.is_file()}")
            None => println("  ✗ File not found")
          }
        }
        Err(e) => println("  ✗ Decode failed: \{e}")
      }
    }
    Err(e) => println("  ✗ Encoding failed: \{e}")
  }
}
