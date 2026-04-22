// Member - represents a file or directory in a ZIP archive

///|
/// Re-export dependencies from other packages
pub using @file {type File}

///|
pub using @types {type Fpath}

///|
pub using @types {type FileMode}

///|
pub using @types {type Ptime}

///|
pub let dos_epoch : Ptime = @types.dos_epoch

///|
pub using @types {fpath_ensure_unix}

///|
pub using @types {fpath_ensure_directoryness}

///|
pub using @types {format_file_mode}

///|
pub using @types {ptime_format}

///|
/// Archive Member - represents a file or directory in a ZIP archive
pub(all) enum MemberKind {
  Dir // Directory entry
  File(File) // File entry with compressed data
}

///|
/// Maximum number of members in a ZIP archive (non-ZIP64)
pub let max_member_count : Int = 65535

///|
/// Maximum path length in ZIP archives
pub let max_path_length : Int = 65535

///|
/// Archive member (file or directory)
pub struct Member {
  path : Fpath
  kind : MemberKind
  mode : FileMode
  mtime : Ptime
}

///|
/// Create a new archive member
#as_free_fn
/// Create a new Member, normalizing path, enforcing length, defaulting mode & mtime.
pub fn Member::make(
  path : Fpath,
  kind : MemberKind,
  mode? : FileMode,
  mtime? : Ptime,
) -> Member raise {
  // Ensure Unix-style path
  let normalized_path = fpath_ensure_unix(path)

  // Ensure directories end with /
  let final_path = match kind {
    Dir => fpath_ensure_directoryness(normalized_path)
    File(_) => normalized_path
  }

  // Check path length
  if final_path.length() > max_path_length {
    fail(
      "Path length \{final_path.length()} exceeds maximum \{max_path_length}",
    )
  }
  // Set default mode
  let file_mode = mode.unwrap_or(
    match kind {
      Dir => FileMode(0o755)
      File(_) => FileMode(0o644)
    },
  )

  // Set default mtime (truncate to dos_epoch if before)
  let modification_time = mtime.unwrap_or(dos_epoch)
  let final_mtime = if modification_time < dos_epoch {
    dos_epoch
  } else {
    modification_time
  }
  { path: final_path, kind, mode: file_mode, mtime: final_mtime }
}

///|
/// Get the path of a member
pub fn Member::path(self : Member) -> Fpath {
  self.path
}

///|
/// Get the kind of a member
pub fn Member::kind(self : Member) -> MemberKind {
  self.kind
}

///|
/// Get the file mode of a member
pub fn Member::mode(self : Member) -> FileMode {
  self.mode
}

///|
/// Get the modification time of a member
pub fn Member::mtime(self : Member) -> Ptime {
  self.mtime
}

///|
/// Check if member is a directory
pub fn Member::is_dir(self : Member) -> Bool {
  match self.kind {
    Dir => true
    File(_) => false
  }
}

///|
/// Check if member is a file
pub fn Member::is_file(self : Member) -> Bool {
  match self.kind {
    Dir => false
    File(_) => true
  }
}

///|
/// Format member info (like ls -l)
/// Short ls -l style listing line.
pub fn Member::format(self : Member) -> String {
  let is_dir_char = match self.kind {
    Dir => "d"
    File(_) => "-"
  }
  let mode_str = format_file_mode(self.mode)
  let size = match self.kind {
    Dir => 0
    File(f) => f.decompressed_size
  }
  let time_str = ptime_format(self.mtime)

  // Format size with padding (8 characters)
  let size_str = size.to_string()
  let spaces_needed = 8 - size_str.length()
  let mut padding = ""
  for i = 0; i < spaces_needed; i = i + 1 {
    padding = padding + " "
  }
  let padded_size = padding + size_str
  is_dir_char +
  mode_str +
  " " +
  padded_size +
  " " +
  time_str +
  " " +
  self.path.to_string()
}

///|
/// Format member info with detailed compression information
/// Extended listing with compression method & ratio (if file).
pub fn Member::format_long(self : Member) -> String {
  let basic = self.format()
  match self.kind {
    Dir => basic
    File(f) => {
      let compression_str = f.compression.to_string()
      let ratio = if f.decompressed_size == 0 {
        "0%"
      } else {
        let pct = f.compressed_size * 100 / f.decompressed_size
        pct.to_string() + "%"
      }
      basic + " [" + compression_str + ", " + ratio + " compressed]"
    }
  }
}
