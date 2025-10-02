// Adler-32 checksum implementation
// Adler-32 checksum as defined in RFC 1950 (zlib format)
// Ported from OCaml zipc library
// Original: Copyright (c) 2023 The zipc programmers
// SPDX-License-Identifier: ISC

///|
/// Unsigned integer types
typealias Int64 as UInt32

///|
/// Helper to convert Int64 to hex string
fn Int64::to_hex_string(self : Int64) -> String {
  let hex_digits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let mut result = ""
  let v = self
  for i = 0; i < 8; i = i + 1 {
    let digit = (v >> (60 - i * 4)).land(0xFL).to_int()
    result = result + Char::to_string(hex_digits[digit])
  }
  result
}

///|
/// Adler-32 state for incremental checksum computation
pub struct Adler32 {
  value : UInt32
} derive(Eq, Show)

///|
/// Adler-32 modulus (largest prime less than 65536)
let adler32_base : UInt32 = 65521L

///|
/// Initialize a new Adler-32 checksum computation
/// Returns an Adler32 state initialized to 1 (the standard starting value)
pub fn Adler32::init() -> Adler32 {
  { value: 1L }
}

///|
/// Finalize the Adler-32 checksum and return the result
/// Returns the computed checksum value
pub fn Adler32::finish(self : Adler32) -> UInt32 {
  self.value
}

///|
/// Update Adler-32 with a sequence of bytes
/// Returns a new Adler32 state with all bytes incorporated
///
/// Implementation processes data in blocks of 5552 bytes to avoid overflow
/// while maintaining efficiency
pub fn Adler32::update_bytes(
  self : Adler32,
  bytes : Bytes,
  start : Int,
  len : Int,
) -> Adler32 {
  let mut s1 = self.value & 0xFFFFL
  let mut s2 = self.value >> 16
  let mut pos = start
  let max = start + len
  while pos < max {
    // Process in blocks to avoid overflow
    let block_len = if len - (pos - start) < 5552 {
      len - (pos - start)
    } else {
      5552
    }
    let block_max = pos + block_len

    // Process block
    while pos < block_max {
      s1 = s1 + bytes[pos].to_int().to_int64()
      s2 = s2 + s1
      pos = pos + 1
    }
    s1 = s1 % adler32_base
    s2 = s2 % adler32_base
  }
  { value: (s2 << 16) | s1 }
}

///|
/// Compute Adler-32 checksum of a byte sequence in one step
/// Convenience function that initializes, updates, and finalizes in one call
pub fn bytes_adler32(bytes : Bytes, start : Int, len : Int) -> UInt32 {
  Adler32::init().update_bytes(bytes, start, len).finish()
}

///|
/// Check if two Adler-32 values match
/// Returns Ok(()) if they match, or an error message if they don't
pub fn check_adler32(expect : UInt32, found : UInt32) -> Result[Unit, String] {
  if expect == found {
    Ok(())
  } else {
    let msg = "Adler-32 mismatch: expected \{expect.to_hex_string()}, found \{found.to_hex_string()}"
    Err(msg)
  }
}
