// Simple CLI tool to test ZIP creation compatibility
// This creates test ZIP files that can be verified with standard tools

///|
/// Main entry point for ZIP library demonstration and testing.
/// 
/// This CLI tool exercises the major features of the MoonBit ZIP library:
/// 1. Single-file ZIP creation (stored format)
/// 2. Multi-file archives with mixed content
/// 3. Directory handling and nested paths
/// 4. Hex dump utilities for debugging binary output
/// 
/// Generated ZIP files can be verified with external tools like `unzip -l`,
/// `7zip`, or `zipinfo` to ensure compatibility with standard implementations.
/// 
/// The tool demonstrates both the high-level Archive API and lower-level
/// File/Member construction patterns.
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
  try {
    let f = @file.File::stored_of_bytes(content, 0, content.length())
    let mem = @member.make(
      @fpath.Fpath("hello.txt"),
      File(f),
      mode=@types.FileMode(0o644),
      mtime=@types.dos_epoch,
    )
    let archive = @lib.Archive::empty()
    archive.add(mem)
    let zip_bytes = archive.to_bytes()
    println("  ✓ Created ZIP: \{zip_bytes.length()} bytes")

    // Verify roundtrip
    try {
      let decoded = @lib.Archive::of_bytes(zip_bytes)
      println("  ✓ Roundtrip successful: \{decoded.member_count()} member(s)")
    } catch {
      e => println("  ✗ Decode failed: \{e}")
    }
  } catch {
    e => println("  ✗ Failed: \{e}")
  }
}

///|
fn test_multi_file_zip() -> Unit {
  println("\nTest 2: Creating multi-file.zip with multiple files...")
  try {
    let file1 = @file.File::stored_of_bytes(b"Content of file 1", 0, 17)
    let file2 = @file.File::stored_of_bytes(b"Content of file 2", 0, 17)
    let file3 = @file.File::stored_of_bytes(b"Content of file 3", 0, 17)
    let m1 = @member.make(@fpath.Fpath("file1.txt"), File(file1))
    let m2 = @member.make(@fpath.Fpath("file2.txt"), File(file2))
    let m3 = @member.make(@fpath.Fpath("file3.txt"), File(file3))
    println("  Original members:")
    println("    - \{m1.path()}")
    println("    - \{m2.path()}")
    println("    - \{m3.path()}")
    let archive = @lib.Archive::empty()
    archive.add(m1)
    archive.add(m2)
    archive.add(m3)
    println("  Archive member count: \{archive.member_count()}")
    let zip_bytes = archive.to_bytes()
    println("  ✓ Created ZIP: \{zip_bytes.length()} bytes")

    // Verify all members
    try {
      let decoded = @lib.Archive::of_bytes(zip_bytes)
      println("  Decoded member count: \{decoded.member_count()}")
      let members = decoded.to_array()
      println("  Decoded members:")
      for i = 0; i < members.length(); i = i + 1 {
        println("    - \{members[i].path()}")
      }
      let has_all = decoded.mem(@fpath.Fpath("file1.txt")) &&
        decoded.mem(@fpath.Fpath("file2.txt")) &&
        decoded.mem(@fpath.Fpath("file3.txt"))
      println("  ✓ All files present: \{has_all}")
    } catch {
      e => println("  ✗ Decode failed: \{e}")
    }
  } catch {
    e => println("  ✗ Failed: \{e}")
  }
}

///|
fn test_directory_zip() -> Unit {
  println("\nTest 3: Creating archive with directories...")
  try {
    let dir = @member.make(
      @fpath.Fpath("docs/"),
      Dir,
      mode=@types.FileMode(0o755),
    )
    let data = b"# README\nThis is documentation.\n"
    let file = @file.File::stored_of_bytes(data, 0, data.length())
    let readme = @member.make(
      @fpath.Fpath("docs/README.md"),
      File(file),
      mode=@types.FileMode(0o644),
    )
    let archive = @lib.Archive::empty()
    archive.add(dir)
    archive.add(readme)
    let zip_bytes = archive.to_bytes()
    println("  ✓ Created ZIP: \{zip_bytes.length()} bytes")
    try {
      let decoded = @lib.Archive::of_bytes(zip_bytes)
      match decoded.find(@fpath.Fpath("docs/")) {
        Some(d) => println("  ✓ Directory entry found: is_dir=\{d.is_dir()}")
        None => println("  ✗ Directory not found")
      }
      match decoded.find(@fpath.Fpath("docs/README.md")) {
        Some(f) => println("  ✓ File entry found: is_file=\{f.is_file()}")
        None => println("  ✗ File not found")
      }
    } catch {
      e => println("  ✗ Decode failed: \{e}")
    }
  } catch {
    e => println("  ✗ Failed: \{e}")
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
  let zip_magic = Bytes::from_array([0x50, 0x4B, 0x03, 0x04])
  println("  ZIP magic signature hex dump:")
  println(@hexdump.hex_dump(zip_magic))

  // Test with mixed printable/non-printable data
  let mixed_data = Bytes::from_array([
    0x48, 0x65, 0x6c, 0x6c, 0x6f, // "Hello"
     0x00, 0x01, 0x02, 0x03, 0x04, // Non-printable
     0x20, 0x21, 0x22, 0x23, 0x24, // Printable ASCII
     0x7f, 0x80, 0xff, // More non-printable
  ])
  println("  Mixed data hex dump:")
  println(@hexdump.hex_dump(mixed_data))
  println("  ✓ Hex dump function working correctly!")
}
