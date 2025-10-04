///|
/// Helper to write 16-bit little-endian integer to buffer
/// Note: stdlib Buffer doesn't have write_uint16_le, so we provide it as extension
fn @buffer.Buffer::write_uint16_le(self : Self, value : UInt16) -> Unit {
  self.write_byte((value & 0xFF).to_byte())
  self.write_byte(((value >> 8) & 0xFF).to_byte())
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
  // Use Buffer from stdlib instead of manual array indexing
  let buf = @buffer.new(size_hint=total_size)
  let central_dir_entries : Array[(Int, Member)] = []

  // Helper to encode a member
  let encode_member = fn(m : Member) {
    let path_bytes = m.path().to_string().utf8()
    let (dos_date, dos_time) = @types.ptime_to_dos_date_time(m.mtime())
    match m.kind() {
      Dir => {
        // Record position for central directory
        let local_header_offset = buf.length()

        // Local file header for directory
        buf.write_uint_le(ZIP_LOCAL_FILE_SIG)
        buf.write_uint16_le(@file.version_needed_default) // version needed
        buf.write_uint16_le(@file.gp_flag_default) // gp flags
        buf.write_uint16_le(0) // compression method (stored)
        buf.write_uint16_le(dos_time) // last mod time
        buf.write_uint16_le(dos_date)
        buf.write_uint_le((0 : UInt)) // CRC-32
        buf.write_uint_le((0 : UInt)) // compressed size
        buf.write_uint_le((0 : UInt)) // uncompressed size
        buf.write_uint16_le(path_bytes.length().to_uint16()) // file name length
        buf.write_uint16_le(0) // extra field length
        buf.write_bytes(path_bytes)
        central_dir_entries.push((local_header_offset, m))
      }
      File(f) => {
        // Record position for central directory
        let local_header_offset = buf.length()

        // Local file header for file
        buf.write_uint_le(ZIP_LOCAL_FILE_SIG)
        buf.write_uint16_le(f.version_needed_to_extract)
        buf.write_uint16_le(f.gp_flags)
        buf.write_uint16_le(f.compression.to_int().to_uint16())
        buf.write_uint16_le(dos_time)
        buf.write_uint16_le(dos_date)
        buf.write_uint_le(f.decompressed_crc32)
        buf.write_uint_le(
          f.compressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        buf.write_uint_le(
          f.decompressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        buf.write_uint16_le(path_bytes.length().to_uint16())
        buf.write_uint16_le(0) // extra field length
        buf.write_bytes(path_bytes)

        // Write compressed data
        buf.write_bytesview(
          f.compressed_bytes[f.start:f.start + f.compressed_size],
        )
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
  let central_dir_start = buf.length()
  for entry in central_dir_entries {
    let (offset, m) = entry
    let path_bytes = m.path().to_string().utf8()
    let (dos_date, dos_time) = @types.ptime_to_dos_date_time(m.mtime())
    buf.write_uint_le(ZIP_CENTRAL_DIR_SIG)
    match m.kind() {
      Dir => {
        buf.write_uint16_le(@file.version_made_by_default)
        buf.write_uint16_le(@file.version_needed_default)
        buf.write_uint16_le(@file.gp_flag_default)
        buf.write_uint16_le(0) // compression
        buf.write_uint16_le(dos_time)
        buf.write_uint16_le(dos_date)
        buf.write_uint_le((0 : UInt)) // CRC
        buf.write_uint_le((0 : UInt)) // compressed size
        buf.write_uint_le((0 : UInt)) // uncompressed size
        buf.write_uint16_le(path_bytes.length().to_uint16()) // file name length
        buf.write_uint16_le(0) // extra field length
        buf.write_uint16_le(0) // file comment length
        buf.write_uint16_le(0) // disk number start
        buf.write_uint16_le(0) // internal file attributes
        buf.write_uint_le(
          (m.mode().to_int() << 16).to_int64().to_int().reinterpret_as_uint(),
        ) // external file attributes
        buf.write_uint_le(offset.to_int64().to_int().reinterpret_as_uint()) // relative offset
        buf.write_bytes(path_bytes)
      }
      File(f) => {
        buf.write_uint16_le(f.version_made_by)
        buf.write_uint16_le(f.version_needed_to_extract)
        buf.write_uint16_le(f.gp_flags)
        buf.write_uint16_le(f.compression.to_int().to_uint16())
        buf.write_uint16_le(dos_time)
        buf.write_uint16_le(dos_date)
        buf.write_uint_le(f.decompressed_crc32)
        buf.write_uint_le(
          f.compressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        buf.write_uint_le(
          f.decompressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        buf.write_uint16_le(path_bytes.length().to_uint16())
        buf.write_uint16_le(0) // extra field length
        buf.write_uint16_le(0) // file comment length
        buf.write_uint16_le(0) // disk number start
        buf.write_uint16_le(0) // internal file attributes
        buf.write_uint_le(
          (m.mode().to_int() << 16).to_int64().to_int().reinterpret_as_uint(),
        ) // external file attributes
        buf.write_uint_le(offset.to_int64().to_int().reinterpret_as_uint()) // relative offset
        buf.write_bytes(path_bytes)
      }
    }
  }
  let central_dir_size = buf.length() - central_dir_start

  // Write end of central directory record
  buf.write_uint_le(ZIP_EOCD_SIG)
  buf.write_uint16_le(0) // disk number
  buf.write_uint16_le(0) // disk with central directory
  buf.write_uint16_le(count.to_uint16()) // entries on this disk
  buf.write_uint16_le(count.to_uint16()) // total entries
  buf.write_uint_le(central_dir_size.to_int64().to_int().reinterpret_as_uint())
  buf.write_uint_le(central_dir_start.to_int64().to_int().reinterpret_as_uint())
  buf.write_uint16_le(0) // comment length
  buf.to_bytes()
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
