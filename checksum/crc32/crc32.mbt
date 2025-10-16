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
/// Pre-computed for fast table-driven CRC calculation. Also used as tables[0] for slice-by-8.
let crc32_table : Array[UInt] = Array::makei(256, i => {
  let mut c = i.reinterpret_as_uint()
  for k in 0..<8 {
    c = if (c & 1) != 0 { crc32_poly ^ (c >> 1) } else { c >> 1 }
  }
  c
})

///|
/// Slice-by-8 tables for high-throughput CRC (8KB total)
/// tables[0] is identical to `crc32_table`; tables[1..7] derived from it.
let crc32_tables : Array[Array[UInt]] = {
  // Initialize all slots referencing base table (will overwrite 1..7)
  let tables : Array[Array[UInt]] = Array::make(8, crc32_table)
  for n in 1..<8 {
    let prev_tbl = tables[n - 1]
    tables[n] = Array::makei(256, i => {
      let prev = prev_tbl[i]
      let shifted = prev >> 8
      let low_index = (prev & 0xFF).reinterpret_as_int()
      shifted ^ crc32_table[low_index]
    })
  }
  tables
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
  if data.length() == 0 {
    return self
  }
  let tables = crc32_tables
  let t0 = crc32_table
  guard tables is [_, t1, t2, t3, t4, t5, t6, t7]
  let Crc32(value0) = self
  let mut v = value0
  // Bulk slice-by-8 loop (process 8 bytes at a time)
  let remain = for slice = data; slice is [u32le(word), b4, b5, b6, b7, .. next]; {
    let c = v ^ word
    // Standard reflected slice-by-8 combination order:
    // v' = T7[c0] ^ T6[c1] ^ T5[c2] ^ T4[c3] ^ T3[b4] ^ T2[b5] ^ T1[b6] ^ T0[b7]
    v = t7[(c & 0xFF).reinterpret_as_int()] ^
      t6[((c >> 8) & 0xFF).reinterpret_as_int()] ^
      t5[((c >> 16) & 0xFF).reinterpret_as_int()] ^
      t4[((c >> 24) & 0xFF).reinterpret_as_int()] ^
      t3[(b4 & 0xFF).to_int()] ^
      t2[(b5 & 0xFF).to_int()] ^
      t1[(b6 & 0xFF).to_int()] ^
      t0[(b7 & 0xFF).to_int()]
    continue next
  } else {
    slice
  }

  // Tail processing for leftover bytes (< 8)
  for byte in remain {
    let byte_u = byte.to_uint()
    let idx = ((v ^ byte_u) & 0xFF).reinterpret_as_int()
    v = t0[idx] ^ (v >> 8)
  }
  Crc32(v)
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
