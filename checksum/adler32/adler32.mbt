// Adler-32 checksum implementation
// Adler-32 checksum as defined in RFC 1950 (zlib format)
// Ported from OCaml zipc library
// Original: Copyright (c) 2023 The zipc programmers
// SPDX-License-Identifier: ISC

///|
/// Helper to convert UInt to hex string
fn UInt::to_hex_string(self : UInt) -> String {
  let hex_digits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let mut result = ""
  let v = self
  for i = 0; i < 8; i = i + 1 {
    let digit = ((v >> (28 - i * 4)) & 0xF).reinterpret_as_int()
    result = result + Char::to_string(hex_digits[digit])
  }
  result
}

///|
/// Adler-32 state for incremental checksum computation
pub struct Adler32(UInt) derive(Eq, Show)

///|
/// Adler-32 modulus (largest prime less than 65536)
let adler32_base : UInt = 65521

///|
/// Initialize a new Adler-32 checksum computation
/// Returns an Adler32 state initialized to 1 (the standard starting value)
pub fn Adler32::init() -> Adler32 {
  Adler32(1)
}

///|
/// Finalize the Adler-32 checksum and return the result
/// Returns the computed checksum value
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
pub fn Adler32::update_bytes(
  self : Adler32,
  bytes : Bytes,
  start : Int,
  len : Int,
) -> Adler32 {
  let Adler32(value) = self
  let mut s1 = value & 0xFFFF
  let mut s2 = value >> 16
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
      s1 = s1 + bytes[pos].to_int().reinterpret_as_uint()
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
pub fn bytes_adler32(bytes : Bytes, start : Int, len : Int) -> UInt {
  Adler32::init().update_bytes(bytes, start, len).finish()
}

///|
/// Check if two Adler-32 values match
/// Returns Ok(()) if they match, or an error message if they don't
pub fn check_adler32(expect : UInt, found : UInt) -> Result[Unit, String] {
  if expect == found {
    Ok(())
  } else {
    let msg = "Adler-32 mismatch: expected \{expect.to_hex_string()}, found \{found.to_hex_string()}"
    Err(msg)
  }
}
