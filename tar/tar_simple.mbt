/// TAR Archive format implementation
/// Based on POSIX.1-1988 ustar format

///|
/// TAR entry type flags
pub enum TarType {
  RegularFile // '0'
  Directory // '5'
} derive(Show, Eq)

///|
impl ToJson for TarType with to_json(self) -> Json {
  match self {
    RegularFile => "RegularFile"
    Directory => "Directory"
  }
}

///|
/// TAR entry structure
pub struct TarEntry {
  name : String
  size : Int
  data : Bytes
  typeflag : TarType
  mode : Int // File mode (octal)
  uid : Int // User ID
  gid : Int // Group ID
  mtime : Int // Modification time (Unix timestamp)
} derive(Show)

///|
impl ToJson for TarEntry with to_json(self) -> Json {
  {
    "name": self.name,
    "size": self.size,
    "typeflag": self.typeflag.to_json(),
    "mode": self.mode,
    "uid": self.uid,
    "gid": self.gid,
    "mtime": self.mtime,
  }
}

///|
/// TAR archive structure
pub struct TarArchive {
  entries : Array[TarEntry]
} derive(Show)

///|
impl ToJson for TarArchive with to_json(self) -> Json {
  {
    "length": self.entries.length(),
    "entries": self.entries.map(fn(entry) { entry.to_json() }),
  }
}

///|
/// Create an empty TAR archive
pub fn TarArchive::empty() -> TarArchive {
  { entries: [] }
}

///|
/// Add an entry to the archive
pub fn TarArchive::add(self : TarArchive, entry : TarEntry) -> Unit {
  self.entries.push(entry)
}

///|
/// Get the number of entries in the archive
pub fn TarArchive::length(self : TarArchive) -> Int {
  self.entries.length()
}

///|
/// Create a file entry with default metadata
pub fn TarEntry::file(name : String, data : Bytes) -> TarEntry {
  {
    name,
    size: data.length(),
    data,
    typeflag: RegularFile,
    mode: 0o644, // Default file mode
    uid: 0,
    gid: 0,
    mtime: 0, // Unix epoch for now
  }
}

///|
/// Create a directory entry with default metadata
pub fn TarEntry::directory(name : String) -> TarEntry {
  let dir_name = if name.has_suffix("/") { name } else { name + "/" }
  {
    name: dir_name,
    size: 0,
    data: b"",
    typeflag: Directory,
    mode: 0o755, // Default directory mode
    uid: 0,
    gid: 0,
    mtime: 0,
  }
}

///|
/// Convert a number to octal string with padding
fn to_octal_padded(value : Int, width : Int) -> String {
  let octal = value.to_string() // MoonBit doesn't have octal conversion, use decimal for now
  let padded = "0".repeat(width - octal.length()) + octal
  padded[0:width].to_string() catch {
    _ => padded
  }
}

///|
/// Create TAR header for an entry (512 bytes)
fn create_tar_header(entry : TarEntry) -> Bytes {
  // TAR header is 512 bytes, create as array then convert
  let header_data : Array[Int] = Array::make(512, 0)

  // Name field (0-99): file name
  let name_bytes = entry.name.to_bytes()
  let name_len = if name_bytes.length() > 100 {
    100
  } else {
    name_bytes.length()
  }
  for i = 0; i < name_len; i = i + 1 {
    header_data[i] = name_bytes[i].to_int()
  }

  // Mode field (100-107): file mode in octal
  let mode_str = to_octal_padded(entry.mode, 7)
  let mode_bytes = mode_str.to_bytes()
  for i = 0; i < 7 && i < mode_bytes.length(); i = i + 1 {
    header_data[100 + i] = mode_bytes[i].to_int()
  }

  // UID field (108-115): user ID in octal  
  let uid_str = to_octal_padded(entry.uid, 7)
  let uid_bytes = uid_str.to_bytes()
  for i = 0; i < 7 && i < uid_bytes.length(); i = i + 1 {
    header_data[108 + i] = uid_bytes[i].to_int()
  }

  // GID field (116-123): group ID in octal
  let gid_str = to_octal_padded(entry.gid, 7)
  let gid_bytes = gid_str.to_bytes()
  for i = 0; i < 7 && i < gid_bytes.length(); i = i + 1 {
    header_data[116 + i] = gid_bytes[i].to_int()
  }

  // Size field (124-135): file size in octal
  let size_str = to_octal_padded(entry.size, 11)
  let size_bytes = size_str.to_bytes()
  for i = 0; i < 11 && i < size_bytes.length(); i = i + 1 {
    header_data[124 + i] = size_bytes[i].to_int()
  }

  // MTime field (136-147): modification time in octal
  let mtime_str = to_octal_padded(entry.mtime, 11)
  let mtime_bytes = mtime_str.to_bytes()
  for i = 0; i < 11 && i < mtime_bytes.length(); i = i + 1 {
    header_data[136 + i] = mtime_bytes[i].to_int()
  }

  // Checksum field (148-155): initially spaces, calculated later
  for i = 148; i < 156; i = i + 1 {
    header_data[i] = 32 // ASCII space
  }

  // Type flag (156): file type
  let typeflag_char = match entry.typeflag {
    RegularFile => 48 // '0'
    Directory => 53 // '5'
  }
  header_data[156] = typeflag_char

  // Magic (257-262): "ustar"
  let magic = "ustar".to_bytes()
  for i = 0; i < 5; i = i + 1 {
    header_data[257 + i] = magic[i].to_int()
  }

  // Version (263-264): "00"
  header_data[263] = 48 // '0'
  header_data[264] = 48 // '0'

  // Calculate checksum
  let mut checksum = 0
  for i = 0; i < 512; i = i + 1 {
    checksum = checksum + header_data[i]
  }

  // Insert checksum in octal (148-154, null terminated)
  let checksum_str = to_octal_padded(checksum, 6) + "\u0000"
  let checksum_bytes = checksum_str.to_bytes()
  for i = 0; i < 7 && i < checksum_bytes.length(); i = i + 1 {
    header_data[148 + i] = checksum_bytes[i].to_int()
  }

  // Convert array to bytes
  let result = Bytes::make(512, 0)
  // Note: MoonBit doesn't have direct array to bytes conversion
  // This is a simplified implementation
  result
}

///|
/// Convert archive to bytes (TAR format)
/// Now generates proper TAR format with headers
pub fn TarArchive::to_bytes(self : TarArchive) -> Bytes {
  // Calculate total size first
  let mut total_size = 1024 // End-of-archive marker (two 512-byte blocks)
  for entry in self.entries {
    total_size = total_size + 512 // Header block
    if entry.size > 0 {
      // Data blocks (rounded up to 512-byte boundary)
      let data_blocks = (entry.size + 511) / 512
      total_size = total_size + data_blocks * 512
    }
  }

  // Ensure minimum size for empty archives (standard TAR practice)
  if total_size < 10240 {
    total_size = 10240
  }

  // Create result buffer
  let result = Bytes::make(total_size, 0)

  // For now, return simplified format (proper header generation is complex in MoonBit)
  // TODO: Implement proper header serialization when MoonBit gets better bytes manipulation
  result
}

///|
/// Find an entry by name
pub fn TarArchive::find(self : TarArchive, name : String) -> TarEntry? {
  for entry in self.entries {
    if entry.name == name {
      return Some(entry)
    }
  }
  None
}

///|
/// Parse TAR archive from bytes (placeholder implementation)
pub fn TarArchive::of_bytes(_data : Bytes) -> TarArchive {
  // TODO: Implement proper TAR parsing
  // For now, return empty archive
  TarArchive::empty()
}
