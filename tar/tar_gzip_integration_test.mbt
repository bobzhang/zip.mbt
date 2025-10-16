/// Integration tests combining TAR + GZIP: create or reuse tar bytes, gzip them,
/// then gunzip and parse, ensuring roundtrip correctness and compression level
/// behavior. Placed in the tar package to reuse embedded fixtures.

///|
/// Programmatic archive -> gzip -> gunzip -> parse
/// (Uses TarEntry::file helper API)

///|
/// // Use fully-qualified package references (@bobzhang/zip/gzip, @bobzhang/zip/deflate)
test "tar_gzip_round_trip_programmatic" {
  let archive = @tar.TarArchive::empty()
  archive.add(@tar.TarEntry::file("a.txt", b"AAA"))
  archive.add(@tar.TarEntry::file("dir/b.txt", b"BBB"))
  let tar_bytes = archive.to_bytes()
  let gz = @gzip.compress(tar_bytes[:])
  let ungz = @gzip.decompress(gz)
  let parsed = @tar.TarArchive::of_bytes(ungz)
  assert_eq(parsed.length(), 2)
  assert_eq(parsed.entries[0].name, "a.txt")
  assert_eq(parsed.entries[1].name, "dir/b.txt")
  let a_txt = @encoding/utf8.decode(parsed.entries[0].data) catch { _ => "" }
  let b_txt = @encoding/utf8.decode(parsed.entries[1].data) catch { _ => "" }
  assert_eq(a_txt, "AAA")
  assert_eq(b_txt, "BBB")
}

///|
/// Embedded fixture tar -> gzip -> gunzip -> identity + parse validation
fn embedded_cases() -> Array[(String, Bytes)] {
  [
    ("test1_simple", test1_simple_tar),
    ("test2_multiple", test2_multiple_tar),
    ("test3_binary", test3_binary_tar),
    ("test4_empty", test4_empty_tar),
  ]
}

///|
test "embedded_tar_gzip_round_trip" {
  let cases = embedded_cases()
  for i = 0; i < cases.length(); i = i + 1 {
    let (label, tar_bytes) = cases[i]
    let gz = @gzip.compress(tar_bytes[:])
    let ungz = @gzip.decompress(gz)
    inspect(ungz == tar_bytes, content="true")
    let parsed = @tar.TarArchive::of_bytes(ungz)
    match label {
      "test1_simple" => assert_eq(parsed.length(), 1)
      "test2_multiple" => assert_eq(parsed.length(), 3)
      "test3_binary" => assert_eq(parsed.length(), 1)
      "test4_empty" => assert_eq(parsed.length(), 0)
      _ => ()
    }
  }
}

///|
/// Compression level impact on a repetitive tar payload.
fn make_repetitive_tar() -> Bytes {
  let mut big = ""
  for i = 0; i < 4096; i = i + 1 {
    big = big + "A"
  }
  let archive = @tar.TarArchive::empty()
  archive.add(@tar.TarEntry::file("repetitive.txt", @encoding/utf8.encode(big)))
  archive.to_bytes()
}

///|
test "tar_gzip_compression_levels" {
  let tar_bytes = make_repetitive_tar()
  let stored = @gzip.compress(tar_bytes[:], level=@deflate.DeflateLevel::None)
  let best = @gzip.compress(tar_bytes[:], level=@deflate.DeflateLevel::Best)
  inspect(stored.length() >= best.length(), content="true")
  let ungz_best = @gzip.decompress(best)
  inspect(ungz_best == tar_bytes, content="true")
}
