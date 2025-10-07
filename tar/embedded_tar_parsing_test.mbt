/// Tests verifying that embedded tar byte arrays produced by pre-build
/// (`tar_embed.js`) can be parsed by our TarArchive implementation.
/// We validate entry counts, names, sizes, and a few content bytes.

///|
test "embedded_tar_parse_test1_simple" {
  let archive = @tar.TarArchive::of_bytes(test1_simple_tar)
  assert_eq(archive.length(), 1)
  let e = archive.entries[0]
  assert_eq(e.name, "test.txt")
  assert_eq(e.size, 16)
  assert_eq(e.data.length(), 16)
  // Updated snapshot id after octal parsing fix
  @json.inspect((e.name, e.size), content=101)
}

///|
test "embedded_tar_parse_test2_multiple" {
  let archive = @tar.TarArchive::of_bytes(test2_multiple_tar)
  guard archive.length() == 3 else {
    fail("expected 3 entries, got ${archive.length()}")
  }
  let names = archive.entries.map(fn(e) -> String { e.name })
  assert_eq(names[0], "readme.txt")
  assert_eq(names[1], "docs/")
  assert_eq(names[2], "docs/guide.md")
  let sizes = archive.entries.map(fn(e) -> Int { e.size })
  // Expected sizes: readme.txt (16), docs/ (0), guide.md (27)
  assert_eq(sizes[0], 16)
  assert_eq(sizes[1], 0)
  assert_eq(sizes[2], 27)
  // Updated snapshot id after octal parsing fix
  @json.inspect((names, sizes), content=102)
}

///|
test "embedded_tar_parse_test3_binary" {
  let archive = @tar.TarArchive::of_bytes(test3_binary_tar)
  assert_eq(archive.length(), 1)
  let entry = archive.entries[0]
  assert_eq(entry.name, "binary.dat")
  assert_eq(entry.size, 18)
  assert_eq(entry.data.length(), 18)
  // Updated snapshot id after octal parsing fix
  @json.inspect((entry.name, entry.size), content=103)
}

///|
test "embedded_tar_parse_test4_empty" {
  let archive = @tar.TarArchive::of_bytes(test4_empty_tar)
  assert_eq(archive.length(), 0)
  // Updated snapshot id after octal parsing fix
  @json.inspect(archive.length(), content=104)
}

///|
test "embedded_tar_roundtrip_basic" {
  // Roundtrip one archive (simple) to ensure to_bytes preserves parse (count & first name)
  let original = @tar.TarArchive::of_bytes(test1_simple_tar)
  let bytes2 = original.to_bytes()
  let parsed2 = @tar.TarArchive::of_bytes(bytes2)
  assert_eq(parsed2.length(), original.length())
  assert_eq(parsed2.entries[0].name, original.entries[0].name)
  @json.inspect(parsed2.length(), content=1)
}
