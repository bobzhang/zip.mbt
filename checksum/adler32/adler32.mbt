// Adler-32 checksum implementation
// Adler-32 checksum as defined in RFC 1950 (zlib format)
// Ported from OCaml zipc library
// Original: Copyright (c) 2023 The zipc programmers
// SPDX-License-Identifier: ISC

///|
/// Adler-32 state for incremental checksum computation
/// Internal Adler state packs s2 (high 16) and s1 (low 16) per RFC 1950.
struct Adler32(UInt) derive(Eq, Show)

///|
/// Adler-32 modulus (largest prime less than 65536)
/// Largest prime < 2^16, modulus for the two accumulators.
let adler32_base : UInt = 65521

///|
/// Initialize a new Adler-32 checksum computation
/// Returns an Adler32 state initialized to 1 (the standard starting value)
/// Initialize new Adler-32 (s1=1, s2=0 encoded as 0x00010001 logically).
pub fn Adler32::init() -> Adler32 {
  Adler32(1)
}

///|
/// Finalize the Adler-32 checksum and return the result
/// Returns the computed checksum value
/// Return the raw packed (s2<<16 | s1) checksum.
pub fn Adler32::finish(self : Adler32) -> UInt {
  let Adler32(value) = self
  value
}

///|
/// Update Adler-32 with a sequence of bytes
/// Returns a new Adler32 state with all bytes incorporated
///
/// Implementation processes data in blocks of 5552 bytes to avoid overflow
/// while maintaining efficiency
/// Incrementally update with bytes[start .. start+len). Processes in 5552-byte chunks to limit overflow.
pub fn Adler32::update_bytes(self : Adler32, data : BytesView) -> Adler32 {
  let Adler32(value) = self
  let mut s1 = value & 0xFFFF
  let mut s2 = value >> 16
  let mut pos = 0
  let len = data.length()
  let max = len
  while pos < max {
    // Process in blocks to avoid overflow
    let block_len = if len - pos < 5552 { len - pos } else { 5552 }
    let block_max = pos + block_len

    // Process block
    while pos < block_max {
      s1 = s1 + data[pos].to_int().reinterpret_as_uint()
      s2 = s2 + s1
      pos = pos + 1
    }
    s1 = s1 % adler32_base
    s2 = s2 % adler32_base
  }
  Adler32((s2 << 16) | s1)
}

///|
/// Compute Adler-32 checksum of a byte sequence in one step
/// Convenience function that initializes, updates, and finalizes in one call
/// One-shot checksum convenience function.
pub fn bytes_adler32(bytes : Bytes, start : Int, len : Int) -> UInt {
  Adler32::init().update_bytes(bytes[start:start + len]).finish()
}

///|
/// Check if two Adler-32 values match
/// Returns Ok(()) if they match, or an error message if they don't
// NOTE: `check_adler32` helper removed. Callers should compare values directly:
//   if expect != found { /* handle mismatch */ }
