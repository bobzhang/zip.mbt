///|
test "ensure_unix" {
  let path : @fpath.Fpath = "dir\\subdir\\file.txt"
  let result = @fpath.ensure_unix(path)
  json_inspect(result, content="dir/subdir/file.txt")
}

///|
test "ensure_directoryness_empty" {
  json_inspect(@fpath.ensure_directoryness(""), content="./")
}

///|
test "ensure_directoryness_no_slash" {
  json_inspect(@fpath.ensure_directoryness("dir"), content="dir/")
}

///|
test "ensure_directoryness_has_slash" {
  json_inspect(@fpath.ensure_directoryness("dir/"), content="dir/")
}

///|
test "sanitize_basic" {
  json_inspect(@fpath.sanitize("a/b/c"), content="a/b/c")
}

///|
test "sanitize_removes_dots" {
  json_inspect(@fpath.sanitize("a/./b/../c"), content="a/b/c")
}

///|
test "sanitize_removes_empty" {
  json_inspect(@fpath.sanitize("a//b///c"), content="a/b/c")
}

///|
test "sanitize_mixed_slashes" {
  json_inspect(@fpath.sanitize("a\\b/c"), content="a/b/c")
}
