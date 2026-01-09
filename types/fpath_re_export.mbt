///|
/// Filepath type and utilities
/// Re-exports from types/fpath package
pub using @fpath {type Fpath}

///|
/// Re-export: normalize separators to '/'.
pub fn fpath_ensure_unix(path : Fpath) -> Fpath {
  @fpath.ensure_unix(path)
}

///|
/// Re-export: ensure trailing slash.
pub fn fpath_ensure_directoryness(path : Fpath) -> Fpath {
  @fpath.ensure_directoryness(path)
}

///|
/// Re-export: sanitize path components.
pub fn fpath_sanitize(path : Fpath) -> Fpath {
  @fpath.sanitize(path)
}
