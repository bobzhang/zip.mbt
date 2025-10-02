///|
/// Filepath type and utilities
/// Re-exports from types/fpath package

pub typealias @fpath.Fpath as Fpath

pub fn fpath_ensure_unix(path : Fpath) -> Fpath {
  @fpath.ensure_unix(path)
}

pub fn fpath_ensure_directoryness(path : Fpath) -> Fpath {
  @fpath.ensure_directoryness(path)
}

pub fn fpath_sanitize(path : Fpath) -> Fpath {
  @fpath.sanitize(path)
}
