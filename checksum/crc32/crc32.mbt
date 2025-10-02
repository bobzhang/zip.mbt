// CRC-32 checksum implementation
// CRC-32 checksum using the polynomial 0xedb88320 (ZIP/gzip standard)
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
/// CRC-32 state for incremental checksum computation
pub struct Crc32 {
  value : UInt32
} derive(Eq, Show)

///|
/// CRC-32 polynomial (reversed, for table-driven algorithm)
let crc32_poly : UInt32 = 0xedb88320L

///|
/// CRC-32 lookup table (256 entries)
/// Pre-computed for fast table-driven CRC calculation
let crc32_table : Array[UInt32] = {
  let table = Array::make(256, 0L)
  for i = 0; i < 256; i = i + 1 {
    let mut c = i.to_int64()
    for k = 0; k < 8; k = k + 1 {
      c = if (c & 1L) != 0L { crc32_poly ^ (c >> 1) } else { c >> 1 }
    }
    table[i] = c
  }
  table
}

///|
/// Initialize a new CRC-32 checksum computation
/// Returns a Crc32 state initialized to the standard starting value
pub fn Crc32::init() -> Crc32 {
  { value: 0xFFFFFFFFL }
}

///|
/// Finalize the CRC-32 checksum and return the result
/// This XORs the internal state with 0xFFFFFFFF as per the standard
pub fn Crc32::finish(self : Crc32) -> UInt32 {
  self.value ^ 0xFFFFFFFFL
}

///|
/// Update CRC-32 with a single byte
/// Returns a new Crc32 state with the byte incorporated
pub fn Crc32::update_byte(self : Crc32, byte : Int) -> Crc32 {
  let index = self.value.lxor(byte.to_int64()).land(0xFFL).to_int()
  let new_value = crc32_table[index] ^ (self.value >> 8)
  { value: new_value }
}

///|
/// Update CRC-32 with a sequence of bytes
/// Returns a new Crc32 state with all bytes incorporated
pub fn Crc32::update_bytes(
  self : Crc32,
  bytes : Bytes,
  start : Int,
  len : Int,
) -> Crc32 {
  let mut crc = self
  for i = start; i < start + len; i = i + 1 {
    crc = crc.update_byte(bytes[i].to_int())
  }
  crc
}

///|
/// Compute CRC-32 checksum of a byte sequence in one step
/// Convenience function that initializes, updates, and finalizes in one call
pub fn bytes_crc32(bytes : Bytes, start : Int, len : Int) -> UInt32 {
  Crc32::init().update_bytes(bytes, start, len).finish()
}

///|
/// Check if two CRC-32 values match
/// Returns Ok(()) if they match, or an error message if they don't
pub fn check_crc32(expect : UInt32, found : UInt32) -> Result[Unit, String] {
  if expect == found {
    Ok(())
  } else {
    let msg = "CRC-32 mismatch: expected \{expect.to_hex_string()}, found \{found.to_hex_string()}"
    Err(msg)
  }
}
