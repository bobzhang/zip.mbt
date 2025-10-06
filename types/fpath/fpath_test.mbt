///|
test "ensure_unix" {
  let path : @fpath.Fpath = "dir\\subdir\\file.txt"
  let result = @fpath.ensure_unix(path)
  @json.inspect(result, content="dir/subdir/file.txt")
}

///|
test "ensure_directoryness_empty" {
  @json.inspect(@fpath.ensure_directoryness(""), content="./")
}

///|
test "ensure_directoryness_no_slash" {
  @json.inspect(@fpath.ensure_directoryness("dir"), content="dir/")
}

///|
test "ensure_directoryness_has_slash" {
  @json.inspect(@fpath.ensure_directoryness("dir/"), content="dir/")
}

///|
test "sanitize_basic" {
  @json.inspect(@fpath.sanitize("a/b/c"), content="a/b/c")
}

///|
test "sanitize_removes_dots" {
  @json.inspect(@fpath.sanitize("a/./b/../c"), content="a/b/c")
}

///|
test "sanitize_removes_empty" {
  @json.inspect(@fpath.sanitize("a//b///c"), content="a/b/c")
}

///|
test "sanitize_mixed_slashes" {
  @json.inspect(@fpath.sanitize("a\\b/c"), content="a/b/c")
}
