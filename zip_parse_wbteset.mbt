///|
/// ZIP magic detection tests
test "zip_magic_local_file_header" {
  // PK\x03\x04
  let data = Bytes::from_array([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00])
  @json.inspect(bytes_has_zip_magic(data), content=true)
}

///|
test "zip_magic_eocd" {
  // PK\x05\x06 (empty archive)
  let data = Bytes::from_array([0x50, 0x4B, 0x05, 0x06, 0x00, 0x00])
  @json.inspect(bytes_has_zip_magic(data), content=true)
}

///|
test "zip_magic_invalid" {
  let data = b"not a zip file"
  @json.inspect(bytes_has_zip_magic(data), content=false)
}

///|
test "zip_magic_too_short" {
  let data = Bytes::from_array([0x50, 0x4B])
  @json.inspect(bytes_has_zip_magic(data), content=false)
}

///|
test "archive_to_bytes_empty" {
  let archive = Archive::empty()
  let bytes = archive.to_bytes()
  // Empty archive: just EOCD (22 bytes)
  @json.inspect((bytes.length(), bytes_has_zip_magic(bytes)), content=[22, true])
}

///|
test "archive_to_bytes_single_file" {
  let data = b"Hello ZIP!"
  let file = @file.File::stored_of_bytes(data, 0, data.length())
  let m = @member.make(@fpath.Fpath("hello.txt"), File(file))
  let archive = Archive::empty()
  archive.add(m)
  let bytes = archive.to_bytes()
  @json.inspect((bytes.length() > 0, bytes_has_zip_magic(bytes)), content=[
    true, true,
  ])
}

///|
test "archive_to_bytes_directory" {
  let m = @member.make(@fpath.Fpath("mydir/"), Dir)
  let archive = Archive::empty()
  archive.add(m)
  let bytes = archive.to_bytes()
  @json.inspect(bytes_has_zip_magic(bytes), content=true)
}

///|
test "archive_to_bytes_multiple_files" {
  let data1 = b"file 1"
  let data2 = b"file 2"
  let file1 = @file.File::stored_of_bytes(data1, 0, data1.length())
  let file2 = @file.File::stored_of_bytes(data2, 0, data2.length())
  let m1 = @member.make(@fpath.Fpath("a.txt"), File(file1))
  let m2 = @member.make(@fpath.Fpath("b.txt"), File(file2))
  let archive = Archive::empty()
  archive.add(m1)
  archive.add(m2)
  let bytes = archive.to_bytes()
  @json.inspect(
    (
      bytes.length() > 100,
      // 2 files
      bytes_has_zip_magic(bytes),
      archive.member_count(),
    ),
    content=[true, true, 2],
  )
}
