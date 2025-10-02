///|
/// Bit-level output writer for deflate compression
/// Accumulates bits and writes complete bytes to the output buffer
pub struct BitWriter {
  dst : @buffer.ByteBuf // Output buffer
  mut bits : Int // Accumulated bits (up to 31 bits)
  mut bits_len : Int // Number of valid bits in 'bits'
}

///|
/// Create a new BitWriter
pub fn BitWriter::new(dst : @buffer.ByteBuf) -> BitWriter {
  { dst, bits: 0, bits_len: 0 }
}

///|
/// Write N bits to the output stream (N <= 16)
/// Bits are written LSB first (as required by deflate format)
pub fn BitWriter::write_bits(self : BitWriter, value : Int, count : Int) -> Unit {
  self.bits = self.bits | (value << self.bits_len)
  self.bits_len = self.bits_len + count
  // Flush complete bytes
  while self.bits_len >= 8 {
    self.dst.add_byte(self.bits & 0xFF)
    self.bits = self.bits >> 8
    self.bits_len = self.bits_len - 8
  }
}

///|
/// Flush any remaining bits to output (pad with zeros)
pub fn BitWriter::flush(self : BitWriter) -> Unit {
  if self.bits_len > 0 {
    self.dst.add_byte(self.bits & 0xFF)
    self.bits = 0
    self.bits_len = 0
  }
}

///|
/// Align to byte boundary (flush and discard partial bits)
pub fn BitWriter::align_to_byte(self : BitWriter) -> Unit {
  if self.bits_len > 0 {
    self.bits = 0
    self.bits_len = 0
  }
}

///|
/// Write a byte directly to output (should be byte-aligned)
pub fn BitWriter::write_byte(self : BitWriter, byte : Int) -> Unit {
  if self.bits_len != 0 {
    abort("BitWriter::write_byte called when not byte-aligned")
  }
  self.dst.add_byte(byte)
}

///|
/// Write a 16-bit little-endian value directly (should be byte-aligned)
pub fn BitWriter::write_uint16_le(self : BitWriter, value : Int) -> Unit {
  if self.bits_len != 0 {
    abort("BitWriter::write_uint16_le called when not byte-aligned")
  }
  self.dst.add_byte(value & 0xFF)
  self.dst.add_byte((value >> 8) & 0xFF)
}
