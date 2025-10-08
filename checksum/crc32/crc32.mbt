// CRC-32 checksum implementation
// CRC-32 checksum using the polynomial 0xedb88320 (ZIP/gzip standard)
// Ported from OCaml zipc library
// Original: Copyright (c) 2023 The zipc programmers
// SPDX-License-Identifier: ISC

///|
/// CRC-32 state for incremental checksum computation
/// Internal state wraps the running (bitwise inverted) CRC value.
struct Crc32(UInt) derive(Eq, Show)

///|
/// CRC-32 polynomial (reversed, for table-driven algorithm)
/// Reversed representation of polynomial 0x04C11DB7 used for little-endian / reflected implementation.
let crc32_poly : UInt = 0xedb88320

///|
/// CRC-32 lookup table (256 entries)
/// Pre-computed for fast table-driven CRC calculation
let crc32_table : Array[UInt] = {
  let table : Array[UInt] = Array::make(256, 0)
  for i = 0; i < 256; i = i + 1 {
    let mut c = i.reinterpret_as_uint()
    for k = 0; k < 8; k = k + 1 {
      c = if (c & 1) != 0 { crc32_poly ^ (c >> 1) } else { c >> 1 }
    }
    table[i] = c
  }
  table
}

///|
/// Initialize a new CRC-32 checksum computation
/// Returns a Crc32 state initialized to the standard starting value
/// Start a new CRC-32 computation (initial value = 0xFFFFFFFF).
pub fn Crc32::init() -> Crc32 {
  Crc32(0xFFFFFFFF)
}

///|
/// Finalize the CRC-32 checksum and return the result
/// This XORs the internal state with 0xFFFFFFFF as per the standard
/// Finalize the checksum (bitwise NOT). After finish() the state should be discarded.
pub fn Crc32::finish(self : Crc32) -> UInt {
  let Crc32(value) = self
  value ^ 0xFFFFFFFF
}

///|
/// Update CRC-32 with a single byte
/// Returns a new Crc32 state with the byte incorporated
/// Feed one byte (0..255). Returns new immutable state.
pub fn Crc32::update_byte(self : Crc32, byte : Int) -> Crc32 {
  let Crc32(value) = self
  let index = ((value ^ byte.reinterpret_as_uint()) & 0xFF).reinterpret_as_int()
  let new_value = crc32_table[index] ^ (value >> 8)
  Crc32(new_value)
}

///|
/// Update CRC-32 with a sequence of bytes
/// Returns a new Crc32 state with all bytes incorporated
/// Bulk update over bytes[start .. start+len). No bounds checking beyond caller guarantees.
pub fn Crc32::update_bytes(self : Crc32, data : BytesView) -> Crc32 {
  let mut crc = self
  for i = 0; i < data.length(); i = i + 1 {
    crc = crc.update_byte(data[i].to_int())
  }
  crc
}

///|
/// Compute CRC-32 checksum of a byte sequence in one step
/// Convenience function that initializes, updates, and finalizes in one call
/// Convenience one-shot helper.
pub fn bytes_crc32(data : BytesView) -> UInt {
  Crc32::init().update_bytes(data).finish()
}

///|
/// Check if two CRC-32 values match
/// Returns Ok(()) if they match, or an error message if they don't
// NOTE: `check_crc32` helper removed. Callers should compare values directly:
//   if expect != found { /* handle mismatch */ }
