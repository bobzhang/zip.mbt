// Gzip compression using the shared deflate implementation.
// Previously this module emitted only a single uncompressed deflate block; that
// approach was functional but ignored the existing deflate encoder/decoder in
// the codebase. We now delegate to @deflate for real compression while still
// constructing/validating the gzip container (RFC 1952).
//
// Compatibility Summary (inlined from removed GZIP_* docs):
// - Header: ID1=1f, ID2=8b, CM=08, FLG=00, MTIME=00000000 (deterministic), XFL=00, OS=ff.
// - Footer: CRC32 (little-endian) + ISIZE (little-endian) exactly per RFC 1952.
// - Determinism: We fix MTIME=0 and XFL=0 so repeated builds are byte‑stable; Python parity via
//   gzip.compress(data, mtime=0, compresslevel in 2..8).
// - Interop: Can decompress Python outputs (compressed dynamic deflate) and vice versa.
// - Non-features (yet): optional filename/comment fields, mtime passthrough, OS tagging diversity.
// - Future: expose optional `mtime? : Int` & `emit_xfl_hint? : Bool` without breaking current reproducibility.

///|
/// Compress data to gzip format (RFC 1952).
/// Parameters:
///   data  - raw uncompressed bytes.
///   level - optional deflate compression level (falls back to encoder default).
/// Produces standard 10-byte header (no extra/name/comment) + deflate stream + CRC32 + ISIZE.
/// Limitations: no support yet for original filename, extra fields, OS-specific metadata.
pub fn compress(
  data : BytesView,
  level? : @deflate.DeflateLevel,
) -> Bytes raise {
  // Optimized assembly: single allocation FixedArray sized exactly to output.
  // Steps: deflate payload (comp), compute CRC/ISIZE, then fill pre-sized array.

  // 1. Deflate payload first so we know size
  let comp = @deflate.deflate(data, level?)

  // 2. Metadata
  let crc32 = @crc32.bytes_crc32(data)
  let isize_u32 = data.length().reinterpret_as_uint()
  // 3. Allocate final buffer (10 header + comp + 8 footer)
  let total = 10 + comp.length() + 8
  let out = FixedArray::make(total, b'\x00')

  // Header
  out[0] = b'\x1f'
  out[1] = b'\x8b'
  out[2] = b'\x08'
  out[3] = b'\x00' // FLG
  // MTIME 4 bytes zero
  out[4] = b'\x00'
  out[5] = b'\x00'
  out[6] = b'\x00'
  out[7] = b'\x00'
  out[8] = b'\x00' // XFL
  out[9] = b'\xff' // OS
  // Payload

  out.blit_from_bytes(10, comp, 0, comp.length())
  let i = 10 + comp.length()
  // Footer CRC32
  out[i] = (crc32 & 0xFF).reinterpret_as_int().to_byte()
  out[i + 1] = ((crc32 >> 8) & 0xFF).reinterpret_as_int().to_byte()
  out[i + 2] = ((crc32 >> 16) & 0xFF).reinterpret_as_int().to_byte()
  out[i + 3] = ((crc32 >> 24) & 0xFF).reinterpret_as_int().to_byte()
  out[i + 4] = (isize_u32 & 0xFF).reinterpret_as_int().to_byte()
  out[i + 5] = ((isize_u32 >> 8) & 0xFF).reinterpret_as_int().to_byte()
  out[i + 6] = ((isize_u32 >> 16) & 0xFF).reinterpret_as_int().to_byte()
  out[i + 7] = ((isize_u32 >> 24) & 0xFF).reinterpret_as_int().to_byte()
  Bytes::from_array(out)
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
pub fn decompress(data : BytesView) -> Bytes raise {
  // Materialize once for header/footer validation & slicing
  // For simplicity, assume minimal header (no extra fields, filename, comment)
  // header is 10 bytes, footer is 8 bytes    
  guard data.length() >= 18 else { fail("Invalid gzip data: too short") }
  guard data is [b'\x1f', b'\x8b', b'\x08', ..] else {
    fail("Invalid gzip magic number or unsupported compression method")
  }
  let header_size = 10
  let footer_size = 8

  // Extract deflate-coded payload slice
  let deflate_start = header_size
  let deflate_end = data.length() - footer_size
  let comp_len = deflate_end - deflate_start
  let comp_slice_view = data[deflate_start:deflate_start + comp_len]
  let decompressed = @deflate.inflate(comp_slice_view)

  // Verify CRC32
  match data[-8:] {
    [u32le(expected_crc32), ..] => {
      let computed_crc32 = @crc32.bytes_crc32(decompressed[:])
      if computed_crc32 != expected_crc32 {
        fail("CRC32 mismatch")
      }
    }
    _ => abort("Invalid gzip data: too short for footer")
  }
  decompressed
}

///|
/// Decompress uncompressed deflate block
// Removed bespoke uncompressed block decoder; inflate from deflate package
// handles all block types we support.
