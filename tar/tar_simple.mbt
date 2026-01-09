/// TAR Archive format implementation
/// Based on POSIX.1-1988 ustar format

///|
/// TAR entry type flags following POSIX ustar subset.
/// Only '0' (regular file) and '5' (directory) currently supported.
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
/// Represents a single header + data payload within a TAR archive.
/// Limitations: path length >100 chars, prefix field, PAX headers not supported.
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
/// Collection of TarEntry values and helpers for (de)serialization.
/// Writer currently pads empty archives to 10KiB (optimization opportunity).
pub struct TarArchive {
  entries : Array[TarEntry]
} derive(Show)

///|
pub impl ToJson for TarArchive with to_json(self) -> Json {
  self.entries.to_json()
}

///|
/// Create an empty TAR archive
/// Create an empty archive.
pub fn TarArchive::empty() -> TarArchive {
  { entries: [] }
}

///|
/// Add an entry to the archive
/// Append an entry (no dedup / ordering guarantees beyond insertion order).
pub fn TarArchive::add(self : TarArchive, entry : TarEntry) -> Unit {
  self.entries.push(entry)
}

///|
/// Get the number of entries in the archive
/// Number of entries currently stored.
pub fn TarArchive::length(self : TarArchive) -> Int {
  self.entries.length()
}

///|
/// Create a file entry with default metadata
/// Construct a regular file entry with default metadata (mode 0644, uid/gid 0, mtime 0).
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
/// Construct a directory entry; ensures a trailing '/'.
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

///|
/// Convert archive to bytes (TAR format)
/// Now generates proper TAR format with headers
/// Serialize archive into ustar-compatible bytes.
/// NOTE: checksum validated by other tools but not re-parsed here; no prefix/long name support.
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
  let result = Array::make(total_size, 0)
  let mut pos = 0

  // Write each entry
  for entry in self.entries {
    // Create and write header
    write_tar_header(result, pos, entry)
    pos = pos + 512

    // Write file data if present
    if entry.size > 0 {
      let data = entry.data
      for i = 0; i < data.length() && i < entry.size; i = i + 1 {
        result[pos + i] = data[i].to_int()
      }
      // Pad to 512-byte boundary
      let data_blocks = (entry.size + 511) / 512
      pos = pos + data_blocks * 512
    }
  }

  // End-of-archive marker (1024 zero bytes) is already in the array
  // Convert Array[Int] to Bytes
  let bytes_array = Array::make(total_size, b'\x00')
  for i = 0; i < total_size; i = i + 1 {
    bytes_array[i] = result[i].to_byte()
  }
  Bytes::from_array(bytes_array)
}

///|
/// Write TAR header to array buffer at given position
fn write_tar_header(buffer : Array[Int], pos : Int, entry : TarEntry) -> Unit {
  // Clear the header area
  for i = 0; i < 512; i = i + 1 {
    buffer[pos + i] = 0
  }

  // Name field (0-99)
  write_string_field(buffer, pos + 0, entry.name, 100)

  // Mode field (100-107) - octal
  write_octal_field(buffer, pos + 100, entry.mode, 8)

  // UID field (108-115) - octal
  write_octal_field(buffer, pos + 108, entry.uid, 8)

  // GID field (116-123) - octal  
  write_octal_field(buffer, pos + 116, entry.gid, 8)

  // Size field (124-135) - octal
  write_octal_field(buffer, pos + 124, entry.size, 12)

  // MTime field (136-147) - octal
  write_octal_field(buffer, pos + 136, entry.mtime, 12)

  // Checksum field (148-155) - initially spaces
  for i = 148; i < 156; i = i + 1 {
    buffer[pos + i] = 32 // ASCII space
  }

  // Type flag (156)
  let typeflag_char = match entry.typeflag {
    RegularFile => 48 // '0'
    Directory => 53 // '5'
  }
  buffer[pos + 156] = typeflag_char

  // Magic (257-262): "ustar"
  write_string_field(buffer, pos + 257, "ustar", 6)

  // Version (263-264): "00"
  buffer[pos + 263] = 48 // '0'
  buffer[pos + 264] = 48 // '0'

  // Calculate and write checksum
  let mut checksum = 0
  for i = 0; i < 512; i = i + 1 {
    checksum = checksum + buffer[pos + i]
  }

  // Write checksum in octal format
  write_octal_field(buffer, pos + 148, checksum, 7)
  buffer[pos + 155] = 0 // Null terminator
}

///|
/// Write string to buffer field with null padding
fn write_string_field(
  buffer : Array[Int],
  pos : Int,
  s : String,
  max_len : Int,
) -> Unit {
  // Convert UTF-16 string to UTF-8 bytes for TAR format
  let bytes = @encoding/utf8.encode(s)
  let len = if bytes.length() > max_len - 1 {
    max_len - 1
  } else {
    bytes.length()
  }
  for i = 0; i < len; i = i + 1 {
    buffer[pos + i] = bytes[i].to_int()
  }
  // Null terminate
  for i = len; i < max_len; i = i + 1 {
    buffer[pos + i] = 0
  }
}

///|
/// Write integer as octal string to buffer field
fn write_octal_field(
  buffer : Array[Int],
  pos : Int,
  value : Int,
  width : Int,
) -> Unit {
  let raw = to_octal_string(value)
  let bytes_raw = @encoding/utf8.encode(raw)
  let len = if bytes_raw.length() > width - 1 {
    width - 1
  } else {
    bytes_raw.length()
  }
  let pad = width - 1 - len
  for i = 0; i < pad; i = i + 1 {
    buffer[pos + i] = 48
  }
  for i = 0; i < len; i = i + 1 {
    buffer[pos + pad + i] = bytes_raw[i].to_int()
  }
  buffer[pos + width - 1] = 0
}

///|
/// Convert integer to octal string representation
fn to_octal_string(value : Int) -> String {
  if value == 0 {
    "0"
  } else {
    let mut n = value
    let mut result = ""
    while n > 0 {
      let digit = n % 8
      result = digit.to_string() + result
      n = n / 8
    }
    result
  }
}

///|
/// Find an entry by name
/// Linear search for an entry by exact name; returns None if not found.
pub fn TarArchive::find(self : TarArchive, name : String) -> TarEntry? {
  for entry in self.entries {
    if entry.name == name {
      return Some(entry)
    }
  }
  None
}

///|
/// Extract a null-terminated string from bytes starting at offset
fn extract_string(data : Bytes, start : Int, max_len : Int) -> String {
  let mut end = start
  let limit = start + max_len
  // Find null terminator or end of field
  while end < limit && end < data.length() && data[end] != 0 {
    end = end + 1
  }
  if end > start {
    let bytes = data[start:end]
    // TAR uses ASCII encoding, not UTF-8, but MoonBit's decode should handle it
    @encoding/utf8.decode(bytes) catch {
      _ => ""
    }
  } else {
    ""
  }
}

///|
/// Parse octal string to integer  
fn parse_octal(s : String) -> Int {
  let mut value = 0
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i].to_int()
    if c == 0 || c == 32 {
      break
    } // NUL or space
    if c >= 48 && c <= 55 { // '0'..'7'
      value = value * 8 + (c - 48)
    } else {
      break
    }
  }
  value
}

///|
/// Check if a TAR header block is empty (all zeros)
fn is_empty_block(data : Bytes, offset : Int) -> Bool {
  if offset + 512 > data.length() {
    return true
  }
  for i = 0; i < 512; i = i + 1 {
    if data[offset + i] != 0 {
      return false
    }
  }
  true
}

///|
/// Parse a single TAR header (512 bytes) and return entry info
fn parse_tar_header(data : Bytes, offset : Int) -> (TarEntry, Int)? {
  if offset + 512 > data.length() {
    return None
  }

  // Check if this is an empty block (end of archive marker)
  if is_empty_block(data, offset) {
    return None
  }

  // Extract header fields according to TAR format
  let name = extract_string(data, offset + 0, 100) // Name (0-99)
  let mode_str = extract_string(data, offset + 100, 8) // Mode (100-107)
  let uid_str = extract_string(data, offset + 108, 8) // UID (108-115)
  let gid_str = extract_string(data, offset + 116, 8) // GID (116-123)
  let size_str = extract_string(data, offset + 124, 12) // Size (124-135)
  let mtime_str = extract_string(data, offset + 136, 12) // MTime (136-147)
  // Checksum at 148-155 (we'll skip validation for now)
  let typeflag_byte = if offset + 156 < data.length() {
    data[offset + 156]
  } else {
    0
  }

  // Check magic "ustar" at offset 257
  let magic = extract_string(data, offset + 257, 5)
  if magic != "ustar" {
    // Not a valid ustar header, might be old format or corrupted
    return None
  }

  // Parse fields
  let mode = parse_octal(mode_str)
  let uid = parse_octal(uid_str)
  let gid = parse_octal(gid_str)
  let size = parse_octal(size_str)
  let mtime = parse_octal(mtime_str)

  // Determine entry type
  let typeflag = match typeflag_byte {
    48 | 0 => RegularFile // '0' or null byte
    53 => Directory // '5'
    _ => RegularFile // Default to regular file for unknown types
  }

  // Calculate data offset (after this header)
  let data_offset = offset + 512

  // Extract file data if it's a regular file
  let file_data = if typeflag == RegularFile && size > 0 {
    if data_offset + size <= data.length() {
      data[data_offset:data_offset + size].to_bytes()
    } else {
      b"" // Truncated file
    }
  } else {
    b"" // Directory or empty file
  }
  let entry = { name, size, data: file_data, typeflag, mode, uid, gid, mtime }

  // Calculate next header position (data padded to 512-byte boundary)
  let data_blocks = (size + 511) / 512
  let next_offset = data_offset + data_blocks * 512
  Some((entry, next_offset))
}

///|
/// Parse TAR archive from bytes
/// Parse a TAR archive from bytes.
/// Skips entries without valid 'ustar' magic and stops at double zero block.
/// Does NOT validate header checksum nor support long names/PAX extensions yet.
pub fn TarArchive::of_bytes(data : Bytes) -> TarArchive {
  let archive = TarArchive::empty()
  let mut offset = 0

  // Parse entries until we hit empty blocks or end of data
  while offset < data.length() {
    match parse_tar_header(data, offset) {
      Some((entry, next_offset)) => {
        archive.add(entry)
        offset = next_offset
      }
      None => {
        // Hit empty block or end - check for double empty block (end marker)
        if is_empty_block(data, offset) && is_empty_block(data, offset + 512) {
          break // End of archive
        }
        offset = offset + 512 // Skip this block and continue
      }
    }
  }
  archive
}
