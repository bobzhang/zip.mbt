// File data in a ZIP archive
// Represents a single file entry with its compressed data and metadata

///|
/// Compression type - Re-exported from types package
pub using @types {type Compression}

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
///
/// Represents a single file entry with its compressed data and metadata.
/// This struct stores the essential information from both the Local File Header
/// and Central Directory File Header as defined in the ZIP specification.
///
/// # ZIP Format Background
/// The ZIP file format stores files in a specific structure:
/// 1. Local file header + compressed data (for each file)
/// 2. Central directory (index of all files)
/// 3. End of central directory record (EOCD)
///
/// This struct combines the metadata from these structures.
pub struct File {
  /// Version made by (2 bytes as per ZIP spec)
  ///
  /// Upper byte: host system (0=DOS, 3=UNIX, etc.)
  /// Lower byte: PKZIP version (e.g., 20 = v2.0, 45 = v4.5)
  ///
  /// Default: 0x0314 = (3 << 8) | 20 = UNIX + PKZIP 2.0
  ///
  /// This field indicates the system and software version that created
  /// the ZIP entry, which can affect how file attributes are interpreted.
  version_made_by : UInt16
  /// Version needed to extract (2 bytes as per ZIP spec)
  ///
  /// Minimum PKZIP version required to extract this file.
  /// - 10 = PKZIP 1.0 (stored/shrunk)
  /// - 20 = PKZIP 2.0 (deflate compression)
  /// - 45 = PKZIP 4.5 (ZIP64 extensions)
  ///
  /// Default: 20 (PKZIP 2.0 for deflate support)
  ///
  /// This ensures compatibility by declaring the minimum version needed
  /// to properly extract and decompress the file data.
  version_needed_to_extract : UInt16
  /// General purpose bit flags (2 bytes as per ZIP spec)
  ///
  /// Bit 0: if set, file is encrypted
  /// Bit 1-2: compression-specific flags
  /// Bit 3: if set, CRC-32 and sizes are in data descriptor after file data
  /// Bit 11 (0x800): if set, filename and comment are UTF-8 encoded
  ///
  /// Default: 0x0800 (UTF-8 encoding enabled)
  ///
  /// These flags control various aspects of file handling, encryption,
  /// and character encoding in the ZIP archive.
  gp_flags : UInt16
  /// Compression method (enum mapped to ZIP spec values)
  ///
  /// ZIP specification compression methods:
  /// - 0 = Stored (no compression)
  /// - 8 = Deflate (RFC 1951)
  /// - 12 = Bzip2
  /// - 14 = LZMA
  /// - 93 = Zstandard
  /// - 95 = XZ
  ///
  /// This implementation primarily supports Stored (0) and Deflate (8).
  /// The Compression enum provides type-safe access to these values.
  compression : Compression
  /// Start offset within compressed_bytes buffer
  ///
  /// When compressed_bytes contains multiple files or has a header,
  /// this indicates where this file's compressed data actually begins.
  /// Allows sharing a single Bytes buffer among multiple Files.
  ///
  /// For standalone file data, this is typically 0.
  start : Int
  /// Compressed size in bytes
  ///
  /// The actual number of bytes occupied by the compressed data
  /// in the compressed_bytes buffer, starting from the 'start' offset.
  ///
  /// Must not exceed max_file_size (2^32 - 1 = 4GB) for non-ZIP64 archives.
  /// For ZIP64 archives, larger sizes are stored in extra fields.
  compressed_size : Int
  /// The compressed data buffer
  ///
  /// Contains the actual compressed file data. This may be:
  /// - The complete compressed stream for this file
  /// - A shared buffer containing multiple files' data
  /// - The original ZIP archive's raw bytes
  ///
  /// Use 'start' and 'compressed_size' to extract this file's data.
  /// Call to_bytes() to decompress and verify the data.
  compressed_bytes : Bytes
  /// Uncompressed size in bytes
  ///
  /// The expected size of the file after decompression.
  /// Used to:
  /// - Pre-allocate output buffers during decompression
  /// - Validate decompression completed successfully
  /// - Display file sizes to users
  ///
  /// Must match the actual decompressed data size for integrity.
  /// Must not exceed max_file_size (4GB) for non-ZIP64 archives.
  decompressed_size : Int
  /// CRC-32 checksum of uncompressed data
  ///
  /// IEEE 802.3 CRC-32 polynomial (0xEDB88320) as defined in RFC 1952.
  /// Computed on the uncompressed file data for integrity verification.
  ///
  /// During extraction:
  /// 1. File is decompressed
  /// 2. CRC-32 is calculated on decompressed data
  /// 3. Result is compared with this stored value
  /// 4. Mismatch indicates data corruption
  ///
  /// This is the primary integrity check in the ZIP format.
  decompressed_crc32 : UInt
}

///|
/// Default values for ZIP file metadata
pub let gp_flag_encrypted : UInt16 = 0x1

///|
pub let gp_flag_utf8 : UInt16 = 0x800

///|
pub let gp_flag_default : UInt16 = gp_flag_utf8

///|
pub let version_made_by_default : UInt16 = (3 << 8) | 20 // UNIX + PKZIP 2.0

///|
pub let version_needed_default : UInt16 = 20 // PKZIP 2.0

///|
/// Maximum file size in non-ZIP64 archives
pub let max_file_size : Int64 = 4294967295L // 2^32 - 1 (4GB)

///|
/// Create file data from compressed bytes
/// Build a File metadata + data wrapper from already-compressed content.
/// Performs size limit checks and applies default versions/flags if optionals are None.
pub fn File::make(
  compressed_bytes : Bytes,
  start : Int,
  compressed_size : Int,
  compression : Compression,
  decompressed_size : Int,
  decompressed_crc32 : UInt,
  version_made_by? : UInt16 = version_made_by_default,
  version_needed? : UInt16 = version_needed_default,
  gp_flags? : UInt16 = gp_flag_default,
) -> File raise {
  if compressed_size.to_int64() > max_file_size ||
    decompressed_size.to_int64() > max_file_size {
    fail(
      "Maximum ZIP file size \{max_file_size} exceeded: compressed=\{compressed_size}, decompressed=\{decompressed_size}",
    )
  }
  {
    version_made_by,
    version_needed_to_extract: version_needed,
    gp_flags,
    compression,
    start,
    compressed_size,
    compressed_bytes,
    decompressed_size,
    decompressed_crc32,
  }
}

///|
/// Create stored (uncompressed) file data from bytes
/// Construct a Stored (uncompressed) File directly from raw bytes.
/// Computes CRC-32 and sets compression=Stored.
pub fn File::stored_of_bytes(
  bytes : Bytes,
  start : Int,
  len : Int,
) -> File raise {
  let crc = @crc32.bytes_crc32(bytes[start:start + len])
  File::make(bytes, start, len, Compression::Stored, len, crc)
}

///|
/// Create deflate-compressed file data from bytes
/// Uses LZ77 + Huffman compression with optimal block type selection
/// Compress raw bytes using DEFLATE at optional level and wrap as File.
/// Chooses dynamic vs fixed Huffman based on size & level.
pub fn File::deflate_of_bytes(
  bytes : Bytes,
  start : Int,
  len : Int,
  level? : @deflate.DeflateLevel,
) -> File raise {
  // Determine compression parameters based on level
  let (good_match, max_chain, use_dynamic) = match level {
    Some(@deflate.DeflateLevel::None) => {
      // No compression, use stored block
      let compressed = @deflate.deflate_stored(bytes[start:start + len])
      let crc = @crc32.bytes_crc32(bytes[start:start + len])
      return File::make(
        compressed,
        0,
        compressed.length(),
        Compression::Deflate,
        len,
        crc,
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
    @deflate.deflate_dynamic(
      bytes[start:start + len],
      true,
      good_match,
      max_chain,
    )
  } else {
    // Use Fixed Huffman for small data or Fast level
    @deflate.deflate_fixed(
      bytes[start:start + len],
      true,
      good_match,
      max_chain,
    )
  }
  let crc = @crc32.bytes_crc32(bytes[start:start + len])
  File::make(compressed, 0, compressed.length(), Compression::Deflate, len, crc)
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
/// Copy out just this file's compressed payload into a fresh Bytes buffer.
pub fn File::compressed_bytes_to_bytes(self : File) -> Bytes {
  let result = Array::make(self.compressed_size, b'\x00')
  for i = 0; i < self.compressed_size; i = i + 1 {
    result[i] = self.compressed_bytes[self.start + i]
  }
  Bytes::from_array(result[:])
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
/// Whether general-purpose bit flag indicates encryption (unsupported here).
pub fn File::is_encrypted(self : File) -> Bool {
  (self.gp_flags & gp_flag_encrypted) != 0
}

///|
/// Check if we can extract (decompress) this file
/// True if decompression supported and file not encrypted.
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
/// Decompress to bytes (or copy if stored) and return (data, computed_crc32) without verifying.
pub fn File::to_bytes_no_crc_check(self : File) -> (Bytes, UInt) raise {
  if self.is_encrypted() {
    fail("Encrypted files are not supported")
  }
  match self.compression {
    Stored => {
      // Just extract the bytes, no decompression needed
      let result_arr = Array::make(self.compressed_size, b'\x00')
      for i = 0; i < self.compressed_size; i = i + 1 {
        result_arr[i] = self.compressed_bytes[self.start + i]
      }
      let result = Bytes::from_array(result_arr[:])
      let crc = @crc32.bytes_crc32(result[:])
      (result, crc)
    }
    Deflate => {
      let decompressed = @deflate.inflate(
        self.compressed_bytes[self.start:self.start + self.compressed_size],
        decompressed_size=self.decompressed_size,
      )
      let crc = @crc32.bytes_crc32(decompressed[:])
      (decompressed, crc)
    }
    _ => fail("Compression format \{self.compression} not supported")
  }
}

///|
/// Decompress file data with CRC check
/// Decompress and validate CRC-32, raising on mismatch.
pub fn File::to_bytes(self : File) -> Bytes raise {
  let (result, found_crc) = self.to_bytes_no_crc_check()
  let expected_crc = self.decompressed_crc32
  if found_crc != expected_crc {
    fail(
      "CRC-32 mismatch: expected \{expected_crc.to_hex_string()}, found \{found_crc.to_hex_string()}",
    )
  }
  result
}
