// File data in a ZIP archive
// Represents a single file entry with its compressed data and metadata

///|
/// Unsigned integer type alias
typealias Int as UInt16

///|
/// Compression type - Re-exported from types package
pub typealias @types.Compression

///|
/// Helper: UInt to hex string
fn UInt::to_hex_string(self : UInt) -> String {
  let hex_digits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let mut result = ""
  let v = self
  for i = 0; i < 8; i = i + 1 {
    let digit = ((v >> (28 - i * 4)) & (0xF : UInt)).reinterpret_as_int()
    result = result + Char::to_string(hex_digits[digit])
  }
  result
}

///|
/// File data in a ZIP archive
pub struct File {
  version_made_by : UInt16
  version_needed_to_extract : UInt16
  gp_flags : UInt16
  compression : Compression
  start : Int // Start offset in compressed_bytes
  compressed_size : Int // Size in compressed_bytes
  compressed_bytes : Bytes // The actual compressed data
  decompressed_size : Int // Expected size when decompressed
  decompressed_crc32 : UInt // Expected CRC-32 of decompressed data
}

///|
/// Default values for ZIP file metadata
pub let gp_flag_encrypted : Int = 0x1

///|
pub let gp_flag_utf8 : Int = 0x800

///|
pub let gp_flag_default : Int = gp_flag_utf8

///|
pub let version_made_by_default : Int = (3 << 8) | 20 // UNIX + PKZIP 2.0

///|
pub let version_needed_default : Int = 20 // PKZIP 2.0

///|
/// Maximum file size in non-ZIP64 archives
pub let max_file_size : Int64 = 4294967295L // 2^32 - 1 (4GB)

///|
/// Create file data from compressed bytes
pub fn File::make(
  compressed_bytes : Bytes,
  start : Int,
  compressed_size : Int,
  compression : Compression,
  decompressed_size : Int,
  decompressed_crc32 : UInt,
  version_made_by : Int?,
  version_needed : Int?,
  gp_flags : Int?,
) -> Result[File, String] {
  if compressed_size.to_int64() > max_file_size ||
    decompressed_size.to_int64() > max_file_size {
    Err(
      "Maximum ZIP file size \{max_file_size} exceeded: compressed=\{compressed_size}, decompressed=\{decompressed_size}",
    )
  } else {
    Ok({
      version_made_by: version_made_by.unwrap_or(version_made_by_default),
      version_needed_to_extract: version_needed.unwrap_or(
        version_needed_default,
      ),
      gp_flags: gp_flags.unwrap_or(gp_flag_default),
      compression,
      start,
      compressed_size,
      compressed_bytes,
      decompressed_size,
      decompressed_crc32,
    })
  }
}

///|
/// Create stored (uncompressed) file data from bytes
pub fn File::stored_of_bytes(
  bytes : Bytes,
  start : Int,
  len : Int,
) -> Result[File, String] {
  let crc = @crc32.bytes_crc32(bytes, start, len)
  File::make(bytes, start, len, Compression::Stored, len, crc, None, None, None)
}

///|
/// Create deflate-compressed file data from bytes
/// Uses LZ77 + Huffman compression with optimal block type selection
pub fn File::deflate_of_bytes(
  bytes : Bytes,
  start : Int,
  len : Int,
  level : @deflate.DeflateLevel?,
) -> Result[File, String] {
  // Determine compression parameters based on level
  let (good_match, max_chain, use_dynamic) = match level {
    Some(@deflate.DeflateLevel::None) => {
      // No compression, use stored blocks
      let compressed = @deflate.deflate_stored(bytes, start, len)
      let crc = @crc32.bytes_crc32(bytes, start, len)
      return File::make(
        compressed,
        0,
        compressed.length(),
        Compression::Deflate,
        len,
        crc,
        None,
        None,
        None,
      )
    }
    Some(@deflate.DeflateLevel::Fast) => (4, 128, false) // Fast: fixed Huffman only
    Some(@deflate.DeflateLevel::Default) | None => (8, 1024, true) // Default: dynamic Huffman
    Some(@deflate.DeflateLevel::Best) => (32, 4096, true) // Best: dynamic Huffman with max effort
  }

  // Choose between Fixed and Dynamic Huffman
  // Dynamic Huffman provides better compression but has header overhead
  // For small data (<256 bytes), fixed Huffman is often better
  let compressed = if use_dynamic && len >= 256 {
    // Use Dynamic Huffman for better compression on larger data
    @deflate.deflate_dynamic(bytes, start, len, true, good_match, max_chain)
  } else {
    // Use Fixed Huffman for small data or Fast level
    @deflate.deflate_fixed(bytes, start, len, true, good_match, max_chain)
  }
  let crc = @crc32.bytes_crc32(bytes, start, len)
  File::make(
    compressed,
    0,
    compressed.length(),
    Compression::Deflate,
    len,
    crc,
    None,
    None,
    None,
  )
}

///|
/// Get compression format
pub fn File::compression(self : File) -> Compression {
  self.compression
}

///|
/// Get start offset in compressed_bytes
pub fn File::start(self : File) -> Int {
  self.start
}

///|
/// Get compressed size
pub fn File::compressed_size(self : File) -> Int {
  self.compressed_size
}

///|
/// Get compressed bytes (the full buffer)
pub fn File::compressed_bytes(self : File) -> Bytes {
  self.compressed_bytes
}

///|
/// Extract just the compressed data as a standalone Bytes object
pub fn File::compressed_bytes_to_bytes(self : File) -> Bytes {
  let result = Array::make(self.compressed_size, b'\x00')
  for i = 0; i < self.compressed_size; i = i + 1 {
    result[i] = self.compressed_bytes[self.start + i]
  }
  Bytes::from_fixedarray(FixedArray::from_iter(result[0:].iter()))
}

///|
/// Get decompressed size
pub fn File::decompressed_size(self : File) -> Int {
  self.decompressed_size
}

///|
/// Get decompressed CRC-32
pub fn File::decompressed_crc32(self : File) -> UInt {
  self.decompressed_crc32
}

///|
/// Get version made by
pub fn File::version_made_by(self : File) -> UInt16 {
  self.version_made_by
}

///|
/// Get version needed to extract
pub fn File::version_needed_to_extract(self : File) -> UInt16 {
  self.version_needed_to_extract
}

///|
/// Get general purpose flags
pub fn File::gp_flags(self : File) -> UInt16 {
  self.gp_flags
}

///|
/// Check if file is encrypted
pub fn File::is_encrypted(self : File) -> Bool {
  (self.gp_flags & gp_flag_encrypted) != 0
}

///|
/// Check if we can extract (decompress) this file
pub fn File::can_extract(self : File) -> Bool {
  if self.is_encrypted() {
    false
  } else {
    match self.compression {
      Stored | Deflate => true
      _ => false
    }
  }
}

///|
/// Decompress file data without CRC check
pub fn File::to_bytes_no_crc_check(self : File) -> (Bytes, UInt) {
  if self.is_encrypted() {
    abort("Encrypted files are not supported")
  }
  match self.compression {
    Stored => {
      // Just extract the bytes, no decompression needed
      let result_arr = Array::make(self.compressed_size, b'\x00')
      for i = 0; i < self.compressed_size; i = i + 1 {
        result_arr[i] = self.compressed_bytes[self.start + i]
      }
      let result = Bytes::from_fixedarray(
        FixedArray::from_iter(result_arr[0:].iter()),
      )
      let crc = @crc32.bytes_crc32(result, 0, result.length())
      (result, crc)
    }
    Deflate =>
      @deflate.inflate_and_crc32(
        self.compressed_bytes,
        self.start,
        self.compressed_size,
        Some(self.decompressed_size),
      )
    _ => abort("Compression format \{self.compression} not supported")
  }
}

///|
/// Decompress file data with CRC check
pub fn File::to_bytes(self : File) -> Bytes {
  let (result, found_crc) = self.to_bytes_no_crc_check()
  let expected_crc = self.decompressed_crc32
  if found_crc != expected_crc {
    abort(
      "CRC-32 mismatch: expected \{expected_crc.to_hex_string()}, found \{found_crc.to_hex_string()}",
    )
  }
  result
}
