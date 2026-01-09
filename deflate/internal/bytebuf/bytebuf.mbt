///|
/// Extensible byte buffer for decompression output
/// Similar to OCaml's Buffer but with self-blit support for LZ77 back-references
/// FIXME(upstream): rename to Buffer does not work global wise
struct ByteBuf {
  mut buffer : FixedArray[Byte]
  mut length : Int
  fixed : Bool // If true, buffer cannot grow (size is known)
}

///|
/// Create a new byte buffer
#as_free_fn
pub fn ByteBuf::new(size_hint~ : Int, fixed? : Bool = false) -> ByteBuf {
  let actual_size = if size_hint == 0 && not(fixed) { 1024 } else { size_hint }
  { buffer: FixedArray::make(actual_size, b'\x00'), length: 0, fixed }
}

///|
/// Get current length of data in buffer
pub fn ByteBuf::length(self : ByteBuf) -> Int {
  self.length
}

///|
/// Get contents as Bytes
pub fn ByteBuf::contents(self : ByteBuf) -> Bytes {
  Bytes::from_array(self.buffer[0:self.length])
}

///|
/// Grow the buffer to ensure it can hold at least 'ensure' bytes
fn ByteBuf::grow(self : ByteBuf, ensure : Int) -> Unit {
  if self.fixed {
    abort("Expected decompression size exceeded")
  }
  let mut new_len = self.buffer.length()
  while new_len < ensure {
    new_len = new_len * 2
  }
  let new_buffer = FixedArray::make(new_len, b'\x00')
  self.buffer.blit_to(new_buffer, len=self.length)
  self.buffer = new_buffer
}

///|
/// Add a single byte to the buffer
pub fn ByteBuf::write_byte(self : ByteBuf, byte : Byte) -> Unit {
  let new_len = self.length + 1
  if new_len > self.buffer.length() {
    self.grow(new_len)
  }
  self.buffer[self.length] = byte
  self.length = new_len
}

///|
/// Add bytes from a Bytes object
pub fn ByteBuf::write_bytes(self : ByteBuf, src : Bytes) -> Unit {
  let new_len = self.length + src.length()
  if new_len > self.buffer.length() {
    self.grow(new_len)
  }
  for i = 0; i < src.length(); i = i + 1 {
    self.buffer[self.length + i] = src[i]
  }
  self.length = new_len
}

///|
pub fn ByteBuf::write_bytesview(self : ByteBuf, src : BytesView) -> Unit {
  let new_len = self.length + src.length()
  if new_len > self.buffer.length() {
    self.grow(new_len)
  }
  for i = 0; i < src.length(); i = i + 1 {
    self.buffer[self.length + i] = src[i]
  }
  self.length = new_len
}

///|
/// Copy bytes from earlier in the buffer (for LZ77 back-references)
/// This handles overlapping copies correctly (needed for RLE patterns)
pub fn ByteBuf::recopy(self : ByteBuf, start : Int, len : Int) -> Unit {
  let new_len = self.length + len
  if new_len > self.buffer.length() {
    self.grow(new_len)
  }
  // Always copy byte-by-byte to handle overlapping correctly
  let dst_start = self.length
  for i = 0; i < len; i = i + 1 {
    self.buffer[dst_start + i] = self.buffer[start + i]
  }
  self.length = new_len
}
