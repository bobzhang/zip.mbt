///|
/// Filepath utilities for ZIP archives
/// 
/// Handles path normalization, sanitization, and conversion between formats

///|
/// File path in ZIP archive
pub typealias String as Fpath

///|
/// Convert backslashes to forward slashes (for Windows paths)
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
  String::from_array(chars)
}

///|
/// Ensure path ends with '/' (for directories)
pub fn ensure_directoryness(path : Fpath) -> Fpath {
  if path == "" {
    "./"
  } else if path[path.length() - 1] == '/' {
    path
  } else {
    path + "/"
  }
}

///|
/// Sanitize a file path by removing dangerous segments
/// Removes: empty segments, ".", "..", and absolute path markers
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
    ""
  } else {
    let mut result = segments[0]
    for i = 1; i < segments.length(); i = i + 1 {
      result = result + "/" + segments[i]
    }
    result
  }
}
