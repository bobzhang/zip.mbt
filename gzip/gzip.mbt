// Gzip compression using the shared deflate implementation.
// Previously this module emitted only a single uncompressed deflate block; that
// approach was functional but ignored the existing deflate encoder/decoder in
// the codebase. We now delegate to @deflate for real compression while still
// constructing/validating the gzip container (RFC 1952).

///|
/// Compress data to gzip format (RFC 1952).
/// Parameters:
///   data  - raw uncompressed bytes.
///   level - optional deflate compression level (falls back to encoder default).
/// Produces standard 10-byte header (no extra/name/comment) + deflate stream + CRC32 + ISIZE.
/// Limitations: no support yet for original filename, extra fields, OS-specific metadata.
pub fn compress(data : Bytes, level? : @deflate.DeflateLevel) -> Bytes raise {
  // --- Header (10 bytes) ---
  let header = FixedArray::make(10, b'\x00')
  header[0] = b'\x1f' // ID1
  header[1] = b'\x8b' // ID2
  header[2] = b'\x08' // CM = deflate
  header[3] = b'\x00' // FLG (no extra/name/comment)
  // MTIME (4 bytes zero)
  header[8] = b'\x00' // XFL (0 = default)
  header[9] = b'\xff' // OS = unknown
  let header_bytes = Bytes::from_fixedarray(header)

  // --- Deflate compressed payload ---
  let comp = match level {
    Some(lv) => @deflate.deflate(data[:], level=lv)
    None => @deflate.deflate(data[:])
  }

  // --- Footer (CRC32 + ISIZE) ---
  let crc32 = @crc32.bytes_crc32(data[:])
  let size = data.length().reinterpret_as_uint()
  let footer = FixedArray::make(8, b'\x00')
  // CRC32 little-endian
  footer[0] = (crc32 & 0xFF).reinterpret_as_int().to_byte()
  footer[1] = ((crc32 >> 8) & 0xFF).reinterpret_as_int().to_byte()
  footer[2] = ((crc32 >> 16) & 0xFF).reinterpret_as_int().to_byte()
  footer[3] = ((crc32 >> 24) & 0xFF).reinterpret_as_int().to_byte()
  // ISIZE (input size modulo 2^32) little-endian
  footer[4] = (size & 0xFF).reinterpret_as_int().to_byte()
  footer[5] = ((size >> 8) & 0xFF).reinterpret_as_int().to_byte()
  footer[6] = ((size >> 16) & 0xFF).reinterpret_as_int().to_byte()
  footer[7] = ((size >> 24) & 0xFF).reinterpret_as_int().to_byte()
  let footer_bytes = Bytes::from_fixedarray(footer)
  header_bytes + comp + footer_bytes
}

///|
/// Backwards-compatible helper retaining old signature with default level.
/// Backwards-compatible one-arg helper (equivalent to compress(data)).
pub fn compress_default(data : Bytes) -> Bytes raise {
  compress(data)
}

///|
/// Create uncompressed deflate block (RFC 1951, section 3.2.4)
// Removed the manual 'create_uncompressed_deflate'; use @deflate.deflate or
// @deflate.deflate_stored if a future optimization wants explicit 'stored'
// blocks. Keeping a tiny shim (commented) for reference:
// fn create_uncompressed_deflate(data: Bytes) -> Bytes raise { @deflate.deflate_stored(data[:]) }

///|
/// Simple gzip decompression.
/// Validates magic, method, and CRC32. Assumes no optional header fields.
/// TODO: support FLG flags (FNAME, FCOMMENT, FEXTRA) and ISIZE validation for >4GB wrap.
pub fn decompress(data : Bytes) -> Bytes raise {
  if data.length() < 18 {
    abort("Invalid gzip data: too short")
  }

  // Check magic
  if data[0] != b'\x1f' || data[1] != b'\x8b' {
    abort("Invalid gzip magic number")
  }

  // Check method
  if data[2] != b'\x08' {
    abort("Unsupported compression method")
  }

  // For simplicity, assume minimal header (no extra fields, filename, comment)
  let header_size = 10
  let footer_size = 8
  let compressed_size = data.length() - header_size - footer_size
  if compressed_size <= 0 {
    abort("Invalid gzip data: no compressed data")
  }

  // Extract deflate-coded payload slice
  let deflate_start = header_size
  let deflate_end = data.length() - footer_size
  if deflate_end < deflate_start {
    abort("Invalid gzip data: corrupt lengths")
  }
  let comp_len = deflate_end - deflate_start
  let comp_slice_view = data[deflate_start:deflate_start + comp_len]
  // Materialize view into Bytes (allocate fixed array then convert)
  // let tmp = FixedArray::make(comp_len, b'\x00')
  // for i = 0; i < comp_len; i = i + 1 {
  //   tmp[i] = comp_slice_view[i]
  // }
  // let comp_slice = Bytes::from_fixedarray(tmp)
  let decompressed = @deflate.inflate(comp_slice_view, None)

  // Verify CRC32
  let crc_offset = data.length() - 8
  let expected_crc32 = data[crc_offset].to_int().reinterpret_as_uint() |
    (data[crc_offset + 1].to_int().reinterpret_as_uint() << 8) |
    (data[crc_offset + 2].to_int().reinterpret_as_uint() << 16) |
    (data[crc_offset + 3].to_int().reinterpret_as_uint() << 24)
  let computed_crc32 = @crc32.bytes_crc32(decompressed[:])
  if computed_crc32 != expected_crc32 {
    abort("CRC32 mismatch")
  }
  decompressed
}

///|
/// Decompress uncompressed deflate block
// Removed bespoke uncompressed block decoder; inflate from deflate package
// handles all block types we support.
