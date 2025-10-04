// File mode utilities for ZIP archives

///|
/// Unix file mode (permission bits)
pub(all) struct FileMode(Int) derive(Eq, Compare, ToJson, FromJson, Hash)

///|
/// Get the integer value of the file mode
pub fn FileMode::to_int(self : FileMode) -> Int {
  self.0
}

///|
/// Create FileMode from integer
pub fn FileMode::from_int(value : Int) -> FileMode {
  FileMode(value)
}

///|
/// String representation for display
pub impl Show for FileMode with output(x, logger) {
  Show::output(x.0, logger)
}

///|
/// Convert to string (returns the integer as string)
pub impl Show for FileMode with to_string(x) {
  x.0.to_string()
}

///|
/// Format Unix file mode like ls -l (e.g., "rwxr-xr-x")
pub fn format_file_mode(mode : FileMode) -> String {
  fn format_entity(m : Int) -> String {
    let r = if (m & 0o4) != 0 { "r" } else { "-" }
    let w = if (m & 0o2) != 0 { "w" } else { "-" }
    let x = if (m & 0o1) != 0 { "x" } else { "-" }
    r + w + x
  }

  let mode_int = mode.0
  format_entity(mode_int >> 6) +
  format_entity(mode_int >> 3) +
  format_entity(mode_int)
}
