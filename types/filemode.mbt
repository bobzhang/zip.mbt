// File mode utilities for ZIP archives

///|
/// Unix file mode (permission bits)
pub typealias Int as FileMode

///|
/// Format Unix file mode like ls -l (e.g., "rwxr-xr-x")
pub fn format_file_mode(mode : FileMode) -> String {
  fn format_entity(m : Int) -> String {
    let r = if (m & 0o4) != 0 { "r" } else { "-" }
    let w = if (m & 0o2) != 0 { "w" } else { "-" }
    let x = if (m & 0o1) != 0 { "x" } else { "-" }
    r + w + x
  }

  format_entity(mode >> 6) + format_entity(mode >> 3) + format_entity(mode)
}
