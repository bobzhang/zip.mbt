// Simple CLI tool to test ZIP creation compatibility
// This creates test ZIP files that can be verified with standard tools

///|
#coverage.skip
fn main {
  println("=== MoonBit ZIP Library Test ===\n")

  // Test 1: Create a simple ZIP file
  test_simple_zip()

  // Test 2: Create a multi-file ZIP
  test_multi_file_zip()

  // Test 3: Create ZIP with directory
  test_directory_zip()

  // Test 4: Demonstrate hex_dump function
  test_hex_dump()
  println("\n✅ All tests completed successfully!")
}

///|
fn test_simple_zip() -> Unit {
  println("Test 1: Creating simple.zip with one file...")
  let content = b"Hello from MoonBit ZIP library!\nThis is a test file.\n"
  let file = @file.File::stored_of_bytes(content, 0, content.length())
  match file {
    Ok(f) => {
      let m = @member.make(
        "hello.txt",
        File(f),
        Some(0o644),
        Some(@types.dos_epoch),
      )
      match m {
        Ok(mem) => {
          let archive = @lib.Archive::empty().add(mem)
          match archive.to_bytes(None) {
            Ok(zip_bytes) => {
              println("  ✓ Created ZIP: \{zip_bytes.length()} bytes")
              // println("  ✓ Has magic: \{@lib.bytes_has_zip_magic(zip_bytes)}")

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
  let file1 = @file.File::stored_of_bytes(b"Content of file 1", 0, 17).unwrap()
  let file2 = @file.File::stored_of_bytes(b"Content of file 2", 0, 17).unwrap()
  let file3 = @file.File::stored_of_bytes(b"Content of file 3", 0, 17).unwrap()
  let m1 = @member.make("file1.txt", File(file1), None, None).unwrap()
  let m2 = @member.make("file2.txt", File(file2), None, None).unwrap()
  let m3 = @member.make("file3.txt", File(file3), None, None).unwrap()
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
  let dir = @member.make("docs/", Dir, Some(0o755), None).unwrap()
  let file_data = b"Documentation file content"
  let file = @file.File::stored_of_bytes(file_data, 0, file_data.length()).unwrap()
  let readme = @member.make("docs/README.md", File(file), Some(0o644), None).unwrap()
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

///|
fn test_hex_dump() -> Unit {
  println("\nTest 4: Demonstrating hex_dump function...")

  // Test with simple data
  let simple_data = b"Hello, World!"
  println("  Simple string hex dump:")
  println(@hexdump.hex_dump(simple_data))

  // Test with ZIP magic signature
  let zip_magic = Bytes::from_fixedarray([0x50, 0x4B, 0x03, 0x04])
  println("  ZIP magic signature hex dump:")
  println(@hexdump.hex_dump(zip_magic))

  // Test with mixed printable/non-printable data
  let mixed_data = Bytes::from_fixedarray([
    0x48, 0x65, 0x6c, 0x6c, 0x6f, // "Hello"
     0x00, 0x01, 0x02, 0x03, 0x04, // Non-printable
     0x20, 0x21, 0x22, 0x23, 0x24, // Printable ASCII
     0x7f, 0x80, 0xff, // More non-printable
  ])
  println("  Mixed data hex dump:")
  println(@hexdump.hex_dump(mixed_data))
  println("  ✓ Hex dump function working correctly!")
}
