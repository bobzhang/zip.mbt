///|
/// Filepath utilities for ZIP archives
/// 
/// Handles path normalization, sanitization, and conversion between formats

///|
/// File path in ZIP archive
pub(all) struct Fpath(String) derive(Eq, Compare, FromJson, Hash)

///|
/// Get the length of the path string
pub fn Fpath::length(self : Fpath) -> Int {
  self.0.length()
}

///|
/// Get character at index
#alias("_[_]")
pub fn Fpath::at(self : Fpath, index : Int) -> Int {
  // FIXME(upstream): ("_[_]") + op_get 
  // would cause weird errors
  self.0[index].to_int()
}

///|
/// Check if path is empty
pub fn Fpath::is_empty(self : Fpath) -> Bool {
  self.0.is_empty()
}

///|
/// String concatenation for paths
/// FIXME(upstream): derive Add
pub impl Add for Fpath with add(x, other) {
  Fpath(x.0 + other.0)
}

///|
/// Convert to string for display
pub impl Show for Fpath with output(x, logger) {
  String::output(x.0, logger)
}

///|
/// FIXME: this is actually needed,
/// otherwise it will quote the string
pub impl Show for Fpath with to_string(x) {
  x.0
}

///|
/// JSON serialization - serializes as plain string
pub impl ToJson for Fpath with to_json(x) {
  Json::string(x.0)
}

///|
/// Convert backslashes to forward slashes (for Windows paths)
/// Normalize path separators to '/' (Windows->Unix style), preserving relative structure.
pub fn ensure_unix(path : Fpath) -> Fpath {
  let chars : Array[Char] = []
  for i = 0; i < path.length(); i = i + 1 {
    let code = path[i]
    let c = code.unsafe_to_char()
    if c == '\\' {
      let _ = chars.push('/')

    } else {
      let _ = chars.push(c)

    }
  }
  Fpath(String::from_array(chars))
}

///|
/// Ensure path ends with '/' (for directories)
/// Ensure trailing '/' for directory semantics (adds if missing; empty -> "./").
pub fn ensure_directoryness(path : Fpath) -> Fpath {
  if path.is_empty() {
    Fpath("./")
  } else if path[path.length() - 1] == '/' {
    path
  } else {
    path + "/"
  }
}

///|
/// Sanitize a file path by removing dangerous segments
/// Removes: empty segments, ".", "..", and absolute path markers
/// Remove dangerous segments ("", ".", "..") and collapse separators (“/” and “\”).
pub fn sanitize(path : Fpath) -> Fpath {
  fn keep_segment(seg : String) -> Bool {
    seg != "" && seg != "." && seg != ".."
  }

  // Split on both / and \
  let segments : Array[String] = []
  let current_chars : Array[Char] = []
  for i = 0; i < path.length(); i = i + 1 {
    let code = path[i]
    let c = code.unsafe_to_char()
    if c == '/' || c == '\\' {
      if current_chars.length() > 0 {
        let current = String::from_array(current_chars)
        if keep_segment(current) {
          let _ = segments.push(current)

        }
        current_chars.clear()
      }
    } else {
      let _ = current_chars.push(c)

    }
  }

  // Don't forget the last segment
  if current_chars.length() > 0 {
    let current = String::from_array(current_chars)
    if keep_segment(current) {
      let _ = segments.push(current)

    }
  }

  // Join with /
  if segments.is_empty() {
    Fpath("")
  } else {
    let mut result = segments[0]
    for i = 1; i < segments.length(); i = i + 1 {
      result = result + "/" + segments[i]
    }
    Fpath(result)
  }
}
