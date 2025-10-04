///|
/// Helper to write 16-bit little-endian integer to buffer
/// Note: Buffer stdlib doesn't have write_uint16_le, so we provide it
fn write_uint16_le(buf : @buffer.Buffer, value : UInt16) -> Unit {
  buf.write_byte((value & 0xFF).to_byte())
  buf.write_byte(((value >> 8) & 0xFF).to_byte())
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
        write_uint16_le(buf, @file.version_needed_default) // version needed
        write_uint16_le(buf, @file.gp_flag_default) // gp flags
        write_uint16_le(buf, 0) // compression method (stored)
        write_uint16_le(buf, dos_time) // last mod time
        write_uint16_le(buf, dos_date)
        buf.write_uint_le((0 : UInt)) // CRC-32
        buf.write_uint_le((0 : UInt)) // compressed size
        buf.write_uint_le((0 : UInt)) // uncompressed size
        write_uint16_le(buf, path_bytes.length().to_uint16()) // file name length
        write_uint16_le(buf, 0) // extra field length
        buf.write_bytes(path_bytes)
        central_dir_entries.push((local_header_offset, m))
      }
      File(f) => {
        // Record position for central directory
        let local_header_offset = buf.length()

        // Local file header for file
        buf.write_uint_le(ZIP_LOCAL_FILE_SIG)
        write_uint16_le(buf, f.version_needed_to_extract)
        write_uint16_le(buf, f.gp_flags)
        write_uint16_le(buf, f.compression.to_int().to_uint16())
        write_uint16_le(buf, dos_time)
        write_uint16_le(buf, dos_date)
        buf.write_uint_le(f.decompressed_crc32)
        buf.write_uint_le(
          f.compressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        buf.write_uint_le(
          f.decompressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        write_uint16_le(buf, path_bytes.length().to_uint16())
        write_uint16_le(buf, 0) // extra field length
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
        write_uint16_le(buf, @file.version_made_by_default)
        write_uint16_le(buf, @file.version_needed_default)
        write_uint16_le(buf, @file.gp_flag_default)
        write_uint16_le(buf, 0) // compression
        write_uint16_le(buf, dos_time)
        write_uint16_le(buf, dos_date)
        buf.write_uint_le((0 : UInt)) // CRC
        buf.write_uint_le((0 : UInt)) // compressed size
        buf.write_uint_le((0 : UInt)) // uncompressed size
        write_uint16_le(buf, path_bytes.length().to_uint16()) // file name length
        write_uint16_le(buf, 0) // extra field length
        write_uint16_le(buf, 0) // file comment length
        write_uint16_le(buf, 0) // disk number start
        write_uint16_le(buf, 0) // internal file attributes
        buf.write_uint_le(
          (m.mode().to_int() << 16).to_int64().to_int().reinterpret_as_uint(),
        ) // external file attributes
        buf.write_uint_le(offset.to_int64().to_int().reinterpret_as_uint()) // relative offset
        buf.write_bytes(path_bytes)
      }
      File(f) => {
        write_uint16_le(buf, f.version_made_by)
        write_uint16_le(buf, f.version_needed_to_extract)
        write_uint16_le(buf, f.gp_flags)
        write_uint16_le(buf, f.compression.to_int().to_uint16())
        write_uint16_le(buf, dos_time)
        write_uint16_le(buf, dos_date)
        buf.write_uint_le(f.decompressed_crc32)
        buf.write_uint_le(
          f.compressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        buf.write_uint_le(
          f.decompressed_size.to_int64().to_int().reinterpret_as_uint(),
        )
        write_uint16_le(buf, path_bytes.length().to_uint16())
        write_uint16_le(buf, 0) // extra field length
        write_uint16_le(buf, 0) // file comment length
        write_uint16_le(buf, 0) // disk number start
        write_uint16_le(buf, 0) // internal file attributes
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
  write_uint16_le(buf, 0) // disk number
  write_uint16_le(buf, 0) // disk with central directory
  write_uint16_le(buf, count.to_uint16()) // entries on this disk
  write_uint16_le(buf, count.to_uint16()) // total entries
  buf.write_uint_le(central_dir_size.to_int64().to_int().reinterpret_as_uint())
  buf.write_uint_le(central_dir_start.to_int64().to_int().reinterpret_as_uint())
  write_uint16_le(buf, 0) // comment length
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
