// zipc - ZIP archive and deflate codec for MoonBit
// Ported from OCaml zipc library
// Original: Copyright (c) 2023 The zipc programmers
// SPDX-License-Identifier: ISC

///|
/// Unsigned integer types
typealias Int as UInt16

///|
typealias Int64 as UInt32

///|
/// CRC-32 checksum implementation
// CRC-32 checksum using the polynomial 0xedb88320 (ZIP standard)

pub struct Crc32 {
  value : UInt32
} derive(Eq, Show)

///|
let crc32_poly : UInt32 = 0xedb88320L

// CRC-32 lookup table (256 entries)

///|
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
/// Crc32 operations
pub fn Crc32::init() -> Crc32 {
  { value: 0xFFFFFFFFL }
}

///|
pub fn Crc32::finish(self : Crc32) -> UInt32 {
  self.value ^ 0xFFFFFFFFL
}

///|
pub fn Crc32::update_byte(self : Crc32, byte : Int) -> Crc32 {
  let index = self.value.lxor(byte.to_int64()).land(0xFFL).to_int()
  let new_value = crc32_table[index] ^ (self.value >> 8)
  { value: new_value }
}

///|
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
pub fn bytes_crc32(bytes : Bytes, start : Int, len : Int) -> UInt32 {
  Crc32::init().update_bytes(bytes, start, len).finish()
}

///|
pub fn check_crc32(expect : UInt32, found : UInt32) -> Result[Unit, String] {
  if expect == found {
    Ok(())
  } else {
    let msg = "CRC-32 mismatch: expected \{expect.to_hex_string()}, found \{found.to_hex_string()}"
    Err(msg)
  }
}

///|
/// Adler-32 checksum implementation
pub struct Adler32 {
  value : UInt32
} derive(Eq, Show)

///|
let adler32_base : UInt32 = 65521L

///|
pub fn Adler32::init() -> Adler32 {
  { value: 1L }
}

///|
pub fn Adler32::finish(self : Adler32) -> UInt32 {
  self.value
}

///|
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
pub fn bytes_adler32(bytes : Bytes, start : Int, len : Int) -> UInt32 {
  Adler32::init().update_bytes(bytes, start, len).finish()
}

///|
pub fn check_adler32(expect : UInt32, found : UInt32) -> Result[Unit, String] {
  if expect == found {
    Ok(())
  } else {
    let msg = "Adler-32 mismatch: expected \{expect.to_hex_string()}, found \{found.to_hex_string()}"
    Err(msg)
  }
}

///|
/// Helper: Int64 to hex string
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
