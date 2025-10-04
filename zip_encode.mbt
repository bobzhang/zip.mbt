///|
/// Helper to write 16-bit little-endian integer to array
fn write_uint16_le(arr : Array[Byte], pos : Int, value : UInt16) -> Unit {
  arr[pos] = (value & 0xFF).to_byte()
  arr[pos + 1] = ((value >> 8) & 0xFF).to_byte()
}

///|
/// Helper to write 32-bit little-endian integer to array
fn write_uint32_le(arr : Array[Byte], pos : Int, value : UInt) -> Unit {
  arr[pos] = (value & (0xFF : UInt)).reinterpret_as_int().to_byte()
  arr[pos + 1] = ((value >> 8) & (0xFF : UInt)).reinterpret_as_int().to_byte()
  arr[pos + 2] = ((value >> 16) & (0xFF : UInt)).reinterpret_as_int().to_byte()
  arr[pos + 3] = ((value >> 24) & (0xFF : UInt)).reinterpret_as_int().to_byte()
}

///|
/// Helper to write bytes to array
fn write_bytes(arr : Array[Byte], pos : Int, data : Bytes) -> Unit {
  for i = 0; i < data.length(); i = i + 1 {
    arr[pos + i] = data[i]
  }
}

///|
/// Calculate the size needed to encode an archive
pub fn Archive::encoding_size(self : Archive) -> Int {
  let mut size = 0
  for _, m in self.members {
    let path_bytes = m.path().to_string().utf8().length()
    // Local file header (30) + path + central directory header (46) + path
    size += 30 + path_bytes + 46 + path_bytes
    match m.kind() {
      Dir => ()
      File(f) => size += f.compressed_size
    }
  }
  // End of central directory record (22)
  size += 22
  size
}

///|
/// Encode archive to bytes
pub fn Archive::to_bytes(self : Archive, first : Fpath?) -> Bytes raise {
  // Check member count limit
  let count = self.member_count()
  if count > @member.max_member_count {
    fail(
      "Archive has \{count} members, exceeds maximum \{@member.max_member_count}",
    )
  }
  let total_size = self.encoding_size()
  // Allocate slightly more space to account for any rounding
  let result = Array::make(total_size + 1024, b'\x00')
  let mut pos = 0
  let central_dir_entries : Array[(Int, Member)] = []

  // Helper to encode a member
  let encode_member = fn(m : Member) {
    let path_bytes = m.path().to_string().utf8()
    let path_len = path_bytes.length()
    let (dos_date, dos_time) = @types.ptime_to_dos_date_time(m.mtime())
    match m.kind() {
      Dir => {
        // Local file header for directory
        write_uint32_le(
          result,
          pos,
          ZIP_LOCAL_FILE_SIG,
          // zip_local_file_sig.to_int64().to_int().reinterpret_as_uint(),
        )
        pos = pos + 4
        write_uint16_le(result, pos, @file.version_needed_default) // version needed
        pos = pos + 2
        write_uint16_le(result, pos, @file.gp_flag_default) // gp flags
        pos = pos + 2
        write_uint16_le(result, pos, 0) // compression method (stored)
        pos = pos + 2
        write_uint16_le(result, pos, dos_time) // last mod time
        pos = pos + 2
        write_uint16_le(result, pos, dos_date)
        pos = pos + 2
        write_uint32_le(result, pos, (0 : UInt)) // CRC-32
        pos = pos + 4
        write_uint32_le(result, pos, (0 : UInt)) // compressed size
        pos = pos + 4
        write_uint32_le(result, pos, (0 : UInt)) // uncompressed size
        pos = pos + 4
        write_uint16_le(result, pos, path_len.to_uint16()) // file name length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // extra field length
        pos = pos + 2
        write_bytes(result, pos, path_bytes)
        pos = pos + path_len
        central_dir_entries.push((pos - 30 - path_len, m))
      }
      File(f) => {
        // Record position for central directory
        let local_header_offset = pos

        // Local file header for file
        write_uint32_le(result, pos, ZIP_LOCAL_FILE_SIG)
        pos = pos + 4
        write_uint16_le(result, pos, f.version_needed_to_extract)
        pos = pos + 2
        write_uint16_le(result, pos, f.gp_flags)
        pos = pos + 2
        write_uint16_le(result, pos, f.compression.to_int().to_uint16())
        pos = pos + 2
        write_uint16_le(result, pos, dos_time)
        pos = pos + 2
        write_uint16_le(result, pos, dos_date)
        pos = pos + 2
        write_uint32_le(result, pos, f.decompressed_crc32)
        pos = pos + 4
        write_uint32_le(
          result,
          pos,
          f.compressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        pos = pos + 4
        write_uint32_le(
          result,
          pos,
          f.decompressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        pos = pos + 4
        write_uint16_le(result, pos, path_len.to_uint16())
        pos = pos + 2
        write_uint16_le(result, pos, 0) // extra field length
        pos = pos + 2
        write_bytes(result, pos, path_bytes)
        pos = pos + path_len

        // Write compressed data
        for i = 0; i < f.compressed_size; i = i + 1 {
          result[pos + i] = f.compressed_bytes[f.start + i]
        }
        pos = pos + f.compressed_size
        central_dir_entries.push((local_header_offset, m))
      }
    }
  }

  // Encode members in order (first, if specified, then rest in sorted order)
  match first {
    Some(first_path) =>
      match self.find(first_path) {
        Some(first_member) => {
          encode_member(first_member)
          // Encode rest in sorted order
          self.members.each(fn(path, m) {
            if path != first_path {
              encode_member(m)
            }
          })
        }
        None =>
          // First path not found, just encode all in sorted order
          self.members.each(fn(_path, m) { encode_member(m) })
      }
    None =>
      // Encode all in sorted order
      self.members.each(fn(_path, m) { encode_member(m) })
  }

  // Write central directory
  let central_dir_start = pos
  for entry in central_dir_entries {
    let (offset, m) = entry
    let path_bytes = m.path().to_string().utf8()
    let path_len = path_bytes.length()
    let (dos_date, dos_time) = @types.ptime_to_dos_date_time(m.mtime())
    write_uint32_le(result, pos, ZIP_CENTRAL_DIR_SIG)
    pos = pos + 4
    match m.kind() {
      Dir => {
        write_uint16_le(result, pos, @file.version_made_by_default)
        pos = pos + 2
        write_uint16_le(result, pos, @file.version_needed_default)
        pos = pos + 2
        write_uint16_le(result, pos, @file.gp_flag_default)
        pos = pos + 2
        write_uint16_le(result, pos, 0) // compression
        pos = pos + 2
        write_uint16_le(result, pos, dos_time)
        pos = pos + 2
        write_uint16_le(result, pos, dos_date)
        pos = pos + 2
        write_uint32_le(result, pos, (0 : UInt)) // CRC
        pos = pos + 4
        write_uint32_le(result, pos, (0 : UInt)) // compressed size
        pos = pos + 4
        write_uint32_le(result, pos, (0 : UInt)) // uncompressed size
        pos = pos + 4
        write_uint16_le(result, pos, path_len.to_uint16()) // file name length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // extra field length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // file comment length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // disk number start
        pos = pos + 2
        write_uint16_le(result, pos, 0) // internal file attributes
        pos = pos + 2
        write_uint32_le(
          result,
          pos,
          (m.mode().to_int() << 16).to_int64().to_int().reinterpret_as_uint(),
        ) // external file attributes
        pos = pos + 4
        write_uint32_le(
          result,
          pos,
          offset.to_int64().to_int().reinterpret_as_uint(),
        ) // relative offset
        pos = pos + 4
        write_bytes(result, pos, path_bytes)
        pos = pos + path_len
      }
      File(f) => {
        write_uint16_le(result, pos, f.version_made_by)
        pos = pos + 2
        write_uint16_le(result, pos, f.version_needed_to_extract)
        pos = pos + 2
        write_uint16_le(result, pos, f.gp_flags)
        pos = pos + 2
        write_uint16_le(result, pos, f.compression.to_int().to_uint16())
        pos = pos + 2
        write_uint16_le(result, pos, dos_time)
        pos = pos + 2
        write_uint16_le(result, pos, dos_date)
        pos = pos + 2
        write_uint32_le(result, pos, f.decompressed_crc32)
        pos = pos + 4
        write_uint32_le(
          result,
          pos,
          f.compressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        pos = pos + 4
        write_uint32_le(
          result,
          pos,
          f.decompressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        pos = pos + 4
        write_uint16_le(result, pos, path_len.to_uint16())
        pos = pos + 2
        write_uint16_le(result, pos, 0) // extra field length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // file comment length
        pos = pos + 2
        write_uint16_le(result, pos, 0) // disk number start
        pos = pos + 2
        write_uint16_le(result, pos, 0) // internal file attributes
        pos = pos + 2
        write_uint32_le(
          result,
          pos,
          (m.mode().to_int() << 16).to_int64().to_int().reinterpret_as_uint(),
        ) // external file attributes
        pos = pos + 4
        write_uint32_le(
          result,
          pos,
          offset.to_int64().to_int().reinterpret_as_uint(),
        ) // relative offset
        pos = pos + 4
        write_bytes(result, pos, path_bytes)
        pos = pos + path_len
      }
    }
  }
  let central_dir_size = pos - central_dir_start

  // Write end of central directory record
  write_uint32_le(result, pos, ZIP_EOCD_SIG)
  pos = pos + 4
  write_uint16_le(result, pos, 0) // disk number
  pos = pos + 2
  write_uint16_le(result, pos, 0) // disk with central directory
  pos = pos + 2
  write_uint16_le(result, pos, count.to_uint16()) // entries on this disk
  pos = pos + 2
  write_uint16_le(result, pos, count.to_uint16()) // total entries
  pos = pos + 2
  write_uint32_le(
    result,
    pos,
    central_dir_size.to_int64().to_int().reinterpret_as_uint(),
  )
  pos = pos + 4
  write_uint32_le(
    result,
    pos,
    central_dir_start.to_int64().to_int().reinterpret_as_uint(),
  )
  pos = pos + 4
  write_uint16_le(result, pos, 0) // comment length
  pos = pos + 2
  Bytes::from_fixedarray(FixedArray::from_iter(result[0:pos].iter()))
}

///|
/// Write archive bytes to a pre-allocated buffer at given offset
/// Returns the number of bytes written or error if buffer is too small
/// Note: Currently not implemented due to Bytes immutability - use to_bytes() instead
pub fn Archive::write_bytes(
  self : Archive,
  _buffer : Bytes,
  offset : Int,
  first : Fpath?,
) -> Int raise {
  let encoded = self.to_bytes(first)
  let size = encoded.length()
  // Note: In MoonBit, Bytes is immutable so we can't write to it
  // This function exists for API compatibility but recommends using to_bytes()
  fail(
    "write_bytes not supported (Bytes is immutable): use to_bytes() instead. Would write \{size} bytes at offset \{offset}",
  )
}
