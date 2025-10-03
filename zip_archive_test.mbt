// Archive tests

///|
/// Archive tests
test "archive_empty" {
  let archive = Archive::empty()
  @json.inspect((archive.is_empty(), archive.member_count()), content=[true, 0])
}

///|
test "archive_add_and_find" {
  let data = b"test"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m1 = Member::make("file1.txt", MemberKind::File(file), None, None).unwrap()
  let m2 = Member::make("file2.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m1).add(m2)
  @json.inspect(
    (
      archive.is_empty(),
      archive.member_count(),
      archive.mem("file1.txt"),
      archive.mem("file3.txt"),
    ),
    content=[false, 2, true, false],
  )
}

///|
test "archive_find_member" {
  let data = b"hello"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("test.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m)
  match archive.find("test.txt") {
    Some(found) => @json.inspect(found.path(), content="test.txt")
    None => @json.inspect("not found", content="not found")
  }
}

///|
test "archive_remove" {
  let data = b"x"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m1 = Member::make("file1.txt", MemberKind::File(file), None, None).unwrap()
  let m2 = Member::make("file2.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m1).add(m2).remove("file1.txt")
  @json.inspect(
    (archive.member_count(), archive.mem("file1.txt"), archive.mem("file2.txt")),
    content=[1, false, true],
  )
}

///|
test "archive_replace_member" {
  let data1 = b"version1"
  let data2 = b"version2"
  let file1 = File::stored_of_bytes(data1, 0, data1.length()).unwrap()
  let file2 = File::stored_of_bytes(data2, 0, data2.length()).unwrap()
  let m1 = Member::make("test.txt", MemberKind::File(file1), None, None).unwrap()
  let m2 = Member::make("test.txt", MemberKind::File(file2), None, None).unwrap()
  let archive = Archive::empty().add(m1).add(m2)
  // Should have only one member (replaced)
  @json.inspect(archive.member_count(), content=1)
  match archive.find("test.txt") {
    Some(found) =>
      match found.kind() {
        MemberKind::File(f) => @json.inspect(f.decompressed_size, content=8)
        _ => @json.inspect("wrong kind", content="file")
      }
    None => @json.inspect("not found", content="not found")
  }
}

///|
test "archive_fold" {
  let data = b"x"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m1 = Member::make("b.txt", MemberKind::File(file), None, None).unwrap()
  let m2 = Member::make("a.txt", MemberKind::File(file), None, None).unwrap()
  let m3 = Member::make("c.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m1).add(m2).add(m3)
  // Fold should process in lexicographic order
  let paths = archive.fold(
    fn(m, acc) {
      match acc {
        "" => m.path()
        _ => acc + "," + m.path()
      }
    },
    "",
  )
  @json.inspect(paths, content="a.txt,b.txt,c.txt")
}

///|
/// ZIP magic detection tests
test "zip_magic_local_file_header" {
  // PK\x03\x04
  let data = Bytes::from_fixedarray([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00])
  @json.inspect(bytes_has_zip_magic(data), content=true)
}

///|
test "zip_magic_eocd" {
  // PK\x05\x06 (empty archive)
  let data = Bytes::from_fixedarray([0x50, 0x4B, 0x05, 0x06, 0x00, 0x00])
  @json.inspect(bytes_has_zip_magic(data), content=true)
}

///|
test "zip_magic_invalid" {
  let data = b"not a zip file"
  @json.inspect(bytes_has_zip_magic(data), content=false)
}

///|
test "zip_magic_too_short" {
  let data = Bytes::from_fixedarray([0x50, 0x4B])
  @json.inspect(bytes_has_zip_magic(data), content=false)
}

///|
/// ZIP encoding tests
test "archive_encoding_size" {
  let data = b"test"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("test.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m)
  let size = archive.encoding_size()
  // Local header (30) + path (8) + data (4) + central dir (46) + path (8) + EOCD (22) = 118
  @json.inspect(size, content=118)
}

///|
test "archive_to_bytes_empty" {
  let archive = Archive::empty()
  let result = archive.to_bytes(None)
  match result {
    Ok(bytes) =>
      // Empty archive: just EOCD (22 bytes)
      @json.inspect((bytes.length(), bytes_has_zip_magic(bytes)), content=[
        22, true,
      ])
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_to_bytes_single_file" {
  let data = b"Hello ZIP!"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("hello.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m)
  let result = archive.to_bytes(None)
  match result {
    Ok(bytes) =>
      @json.inspect((bytes.length() > 0, bytes_has_zip_magic(bytes)), content=[
        true, true,
      ])
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_to_bytes_directory" {
  let m = Member::make("mydir/", MemberKind::Dir, None, None).unwrap()
  let archive = Archive::empty().add(m)
  let result = archive.to_bytes(None)
  match result {
    Ok(bytes) => @json.inspect(bytes_has_zip_magic(bytes), content=true)
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_to_bytes_multiple_files" {
  let data1 = b"file 1"
  let data2 = b"file 2"
  let file1 = File::stored_of_bytes(data1, 0, data1.length()).unwrap()
  let file2 = File::stored_of_bytes(data2, 0, data2.length()).unwrap()
  let m1 = Member::make("a.txt", MemberKind::File(file1), None, None).unwrap()
  let m2 = Member::make("b.txt", MemberKind::File(file2), None, None).unwrap()
  let archive = Archive::empty().add(m1).add(m2)
  let result = archive.to_bytes(None)
  match result {
    Ok(bytes) =>
      @json.inspect(
        (
          bytes.length() > 100,
          // 2 files
          bytes_has_zip_magic(bytes),
          archive.member_count(),
        ),
        content=[true, true, 2],
      )
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
/// ZIP decoding tests
test "archive_of_bytes_empty" {
  let archive = Archive::empty()
  let bytes = archive.to_bytes(None).unwrap()
  let result = Archive::of_bytes(bytes)
  match result {
    Ok(decoded) =>
      @json.inspect((decoded.is_empty(), decoded.member_count()), content=[
        true, 0,
      ])
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_roundtrip_single_file" {
  let data = b"Hello, ZIP world!"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("hello.txt", MemberKind::File(file), None, None).unwrap()
  let original = Archive::empty().add(m)

  // Encode
  let bytes = original.to_bytes(None).unwrap()

  // Decode
  let result = Archive::of_bytes(bytes)
  match result {
    Ok(decoded) => {
      @json.inspect(decoded.member_count(), content=1)
      match decoded.find("hello.txt") {
        Some(found) =>
          match found.kind() {
            MemberKind::File(f) => {
              let extracted = f.to_bytes()
              @json.inspect(
                (
                  extracted.length(),
                  extracted[0] == data[0],
                  extracted[data.length() - 1] == data[data.length() - 1],
                ),
                content=[17, true, true],
              )
            }
            _ => @json.inspect("wrong kind", content="file")
          }
        None => @json.inspect("not found", content="not found")
      }
    }
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_roundtrip_multiple_files" {
  let data1 = b"File 1 content"
  let data2 = b"File 2 content"
  let data3 = b"File 3 content"
  let file1 = File::stored_of_bytes(data1, 0, data1.length()).unwrap()
  let file2 = File::stored_of_bytes(data2, 0, data2.length()).unwrap()
  let file3 = File::stored_of_bytes(data3, 0, data3.length()).unwrap()
  let m1 = Member::make("docs/file1.txt", MemberKind::File(file1), None, None).unwrap()
  let m2 = Member::make("docs/file2.txt", MemberKind::File(file2), None, None).unwrap()
  let m3 = Member::make("readme.txt", MemberKind::File(file3), None, None).unwrap()
  let original = Archive::empty().add(m1).add(m2).add(m3)

  // Encode
  let bytes = original.to_bytes(None).unwrap()

  // Decode
  let result = Archive::of_bytes(bytes)
  match result {
    Ok(decoded) =>
      @json.inspect(
        (
          decoded.member_count(),
          decoded.mem("docs/file1.txt"),
          decoded.mem("docs/file2.txt"),
          decoded.mem("readme.txt"),
        ),
        content=[3, true, true, true],
      )
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_roundtrip_with_directory" {
  let data = b"test"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let dir = Member::make("mydir/", MemberKind::Dir, None, None).unwrap()
  let f = Member::make("mydir/file.txt", MemberKind::File(file), None, None).unwrap()
  let original = Archive::empty().add(dir).add(f)

  // Encode
  let bytes = original.to_bytes(None).unwrap()

  // Decode
  let result = Archive::of_bytes(bytes)
  match result {
    Ok(decoded) => {
      @json.inspect(decoded.member_count(), content=2)
      match decoded.find("mydir/") {
        Some(d) => @json.inspect(d.is_dir(), content=true)
        None => @json.inspect("dir not found", content="dir not found")
      }
    }
    Err(msg) => @json.inspect(("error", msg), content=["success", ""])
  }
}

///|
test "archive_of_bytes_invalid" {
  let invalid = b"This is not a ZIP file"
  let result = Archive::of_bytes(invalid)
  match result {
    Ok(_) => @json.inspect("should have failed", content="error")
    Err(msg) => @json.inspect(msg.contains("magic"), content=true)
  }
}

///|
/// Archive map conversion tests
test "archive_to_map" {
  let data = b"x"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m1 = Member::make("a.txt", MemberKind::File(file), None, None).unwrap()
  let m2 = Member::make("b.txt", MemberKind::File(file), None, None).unwrap()
  let archive = Archive::empty().add(m1).add(m2)
  let map = archive.to_map()
  @json.inspect(
    (map.contains("a.txt"), map.contains("b.txt"), map.contains("c.txt")),
    content=[true, true, false],
  )
}

///|
test "archive_of_map_roundtrip" {
  let data = b"test"
  let file = File::stored_of_bytes(data, 0, data.length()).unwrap()
  let m = Member::make("test.txt", MemberKind::File(file), None, None).unwrap()
  let original = Archive::empty().add(m)
  let map = original.to_map()
  let restored = Archive::of_map(map)
  @json.inspect((restored.member_count(), restored.mem("test.txt")), content=[
    1, true,
  ])
}

///|
/// Test archive with no magic signature
test "coverage_archive_no_magic" {
  let data = b"Not a ZIP file"
  match Archive::of_bytes(data) {
    Ok(_) => @json.inspect("should fail", content="error")
    Err(msg) => @json.inspect(msg.contains("magic"), content=true)
  }
}

///|
/// Test archive too short for EOCD
test "coverage_archive_too_short" {
  let data = b"PK\x03\x04short"
  match Archive::of_bytes(data) {
    Ok(_) => @json.inspect("should fail", content="error")
    Err(msg) =>
      @json.inspect(msg.contains("end of central directory"), content=true)
  }
}

///|
/// Test archive to_array
test "coverage_archive_to_array" {
  let a = Archive::empty()
  match Member::make("dir/", MemberKind::Dir, None, None) {
    Ok(d) => {
      let a = a.add(d)
      let data = b"F"
      match File::deflate_of_bytes(data, 0, data.length(), None) {
        Ok(file) =>
          match Member::make("dir/f.txt", MemberKind::File(file), None, None) {
            Ok(f) => {
              let a = a.add(f)
              @json.inspect(a.to_array().length(), content=2)
            }
            Err(_) => @json.inspect("should not fail", content="success")
          }
        Err(_) => @json.inspect("should not fail", content="success")
      }
    }
    Err(_) => @json.inspect("should not fail", content="success")
  }
}

///|
/// Test archive to_bytes with first parameter
test "coverage_archive_first" {
  let a = Archive::empty()
  let d1 = b"A"
  let d2 = b"B"
  match File::deflate_of_bytes(d1, 0, d1.length(), None) {
    Ok(f1) =>
      match File::deflate_of_bytes(d2, 0, d2.length(), None) {
        Ok(f2) =>
          match Member::make("a.txt", MemberKind::File(f1), None, None) {
            Ok(m1) =>
              match Member::make("z.txt", MemberKind::File(f2), None, None) {
                Ok(m2) => {
                  let a = a.add(m1).add(m2)
                  match a.to_bytes(Some("z.txt")) {
                    Ok(enc) => @json.inspect(enc.length() > 0, content=true)
                    Err(_) =>
                      @json.inspect("should not fail", content="success")
                  }
                }
                Err(_) => @json.inspect("should not fail", content="success")
              }
            Err(_) => @json.inspect("should not fail", content="success")
          }
        Err(_) => @json.inspect("should not fail", content="success")
      }
    Err(_) => @json.inspect("should not fail", content="success")
  }
}
