// Simple gzip compression using uncompressed deflate blocks
// This creates valid gzip files that are compatible with Python's gzip
// but without actual compression for simplicity

///|
/// Simple gzip compression
pub fn compress(data : Bytes) -> Bytes {
  // Build minimal gzip header (10 bytes)
  let header = FixedArray::make(10, b'\x00')
  header[0] = b'\x1f' // Magic 1
  header[1] = b'\x8b' // Magic 2  
  header[2] = b'\x08' // Deflate method
  header[3] = b'\x00' // No flags
  // header[4-7] = mtime (already zero)
  header[8] = b'\x00' // Extra flags
  header[9] = b'\xff' // OS (unknown)
  let header_bytes = Bytes::from_fixedarray(header)

  // Create uncompressed deflate block
  let deflate_data = create_uncompressed_deflate(data)

  // Compute CRC32 of original data (should match Python's zlib.crc32)
  let crc32 = @crc32.bytes_crc32(data, 0, data.length())

  // Build footer (8 bytes): CRC32 + size (both little-endian)
  let footer = FixedArray::make(8, b'\x00')
  // CRC32 in little-endian format
  footer[0] = (crc32 & 0xFF).reinterpret_as_int().to_byte()
  footer[1] = ((crc32 >> 8) & 0xFF).reinterpret_as_int().to_byte()
  footer[2] = ((crc32 >> 16) & 0xFF).reinterpret_as_int().to_byte()
  footer[3] = ((crc32 >> 24) & 0xFF).reinterpret_as_int().to_byte()

  // Size in little-endian format
  let size = data.length().reinterpret_as_uint()
  footer[4] = (size & 0xFF).reinterpret_as_int().to_byte()
  footer[5] = ((size >> 8) & 0xFF).reinterpret_as_int().to_byte()
  footer[6] = ((size >> 16) & 0xFF).reinterpret_as_int().to_byte()
  footer[7] = ((size >> 24) & 0xFF).reinterpret_as_int().to_byte()
  let footer_bytes = Bytes::from_fixedarray(footer)
  header_bytes + deflate_data + footer_bytes
}

///|
/// Create uncompressed deflate block (RFC 1951, section 3.2.4)
fn create_uncompressed_deflate(data : Bytes) -> Bytes {
  let len = data.length()

  // Block header: BFINAL=1, BTYPE=00 (uncompressed)
  let header_size = 5 // 1 byte header + 2 bytes len + 2 bytes nlen
  let total_size = header_size + len
  let result = FixedArray::make(total_size, b'\x00')

  // Block header: BFINAL=1 (last block), BTYPE=00 (uncompressed)
  result[0] = b'\x01' // 00000001 in binary

  // Length (little-endian)
  result[1] = (len & 0xFF).to_byte()
  result[2] = ((len >> 8) & 0xFF).to_byte()

  // One's complement of length (little-endian)
  let nlen = len ^ 0xFFFF
  result[3] = (nlen & 0xFF).to_byte()
  result[4] = ((nlen >> 8) & 0xFF).to_byte()

  // Copy original data
  for i = 0; i < len; i = i + 1 {
    result[header_size + i] = data[i]
  }
  Bytes::from_fixedarray(result)
}

///|
/// Simple gzip decompression
pub fn decompress(data : Bytes) -> Bytes {
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

  // Extract deflate data
  let deflate_start = header_size
  let deflate_end = data.length() - footer_size

  // Decompress uncompressed deflate block
  let decompressed = decompress_uncompressed_deflate(
    data, deflate_start, deflate_end,
  )

  // Verify CRC32
  let crc_offset = data.length() - 8
  let expected_crc32 = data[crc_offset].to_int().reinterpret_as_uint() |
    (data[crc_offset + 1].to_int().reinterpret_as_uint() << 8) |
    (data[crc_offset + 2].to_int().reinterpret_as_uint() << 16) |
    (data[crc_offset + 3].to_int().reinterpret_as_uint() << 24)
  let computed_crc32 = @bobzhang/zip/checksum/crc32.bytes_crc32(
    decompressed,
    0,
    decompressed.length(),
  )
  if computed_crc32 != expected_crc32 {
    abort("CRC32 mismatch")
  }
  decompressed
}

///|
/// Decompress uncompressed deflate block
fn decompress_uncompressed_deflate(
  data : Bytes,
  start : Int,
  end : Int,
) -> Bytes {
  if end - start < 5 {
    abort("Invalid deflate data: too short")
  }

  // Check block header
  let header = data[start]
  if header != b'\x01' { // BFINAL=1, BTYPE=00
    abort("Only uncompressed deflate blocks supported")
  }

  // Read length
  let len = data[start + 1].to_int() | (data[start + 2].to_int() << 8)
  let nlen = data[start + 3].to_int() | (data[start + 4].to_int() << 8)

  // Verify length complement
  if len != (nlen ^ 0xFFFF) {
    abort("Invalid deflate block: length mismatch")
  }

  // Check we have enough data
  if end - start < 5 + len {
    abort("Invalid deflate data: truncated")
  }

  // Extract the uncompressed data
  let result = FixedArray::make(len, b'\x00')
  for i = 0; i < len; i = i + 1 {
    result[i] = data[start + 5 + i]
  }
  Bytes::from_fixedarray(result)
}
