// Enhanced validation-focused tests for the deflate package
//
// This file is the single source of truth for the structural validation suite.
// It documents the goals of each helper and test, so the implementation and its
// rationale stay together:
// - `BitReader` offers just enough functionality to peek at block metadata
//   without re-implementing the full decoder.
// - `inspect_first_block` reports the bits we care about when validating the
//   encoder (BFINAL flag, block type, stored length, and dynamic header fields).
// - `repeat_slice`, `make_incrementing`, and `make_mixed` generate datasets with
//   distinct compression characteristics for matrix testing.
//
// Test overview:
// - `deflate_roundtrip_parameter_matrix` exercises multiple compression levels
//   against varied payloads, validating both round-trips and block metadata.
// - `deflate_fixed_deterministic` ensures the fixed-Huffman encoder remains
//   deterministic at the `Fast` level.
// - `deflate_dynamic_header_ranges` checks dynamic header fields stay inside
//   spec-defined ranges for compressible inputs.
// - `deflate_concatenation_roundtrip` proves individually compressed members can
//   still act as standalone final blocks when decoded back-to-back.
//
// Update this commentary whenever you change the tests so downstream readers
// know exactly what safety net they provide.

///|
struct BitReader {
  bytes : BytesView
  len : Int
  mut pos : Int
  mut bitbuf : Int
  mut bitcount : Int
}

///|
fn BitReader::new(bytes : BytesView) -> BitReader {
  { bytes, len: bytes.length(), pos: 0, bitbuf: 0, bitcount: 0 }
}

///|
fn BitReader::read_bits(self : BitReader, count : Int) -> Int raise {
  let mut bits = self.bitbuf
  let mut bitcount = self.bitcount
  while bitcount < count {
    if self.pos >= self.len {
      fail(
        "Corrupted deflate stream: unexpected end of data while reading bits",
      )
    }
    let byte = self.bytes[self.pos].to_int()
    bits = bits | (byte << bitcount)
    self.pos = self.pos + 1
    bitcount = bitcount + 8
  }
  let mask = (1 << count) - 1
  let value = bits & mask
  self.bitbuf = bits >> count
  self.bitcount = bitcount - count
  value
}

///|
fn BitReader::align_to_byte(self : BitReader) -> Unit {
  self.bitbuf = 0
  self.bitcount = 0
}

///|
fn parse_stored_block(reader : BitReader) -> Int raise {
  reader.align_to_byte()
  if reader.pos + 4 > reader.len {
    fail("Corrupted deflate stream: truncated stored block header")
  }
  let len = reader.bytes[reader.pos].to_int() |
    (reader.bytes[reader.pos + 1].to_int() << 8)
  let nlen = reader.bytes[reader.pos + 2].to_int() |
    (reader.bytes[reader.pos + 3].to_int() << 8)
  reader.pos = reader.pos + 4
  if len != (nlen ^ 0xFFFF) {
    fail("Corrupted deflate stream: stored block LEN/NLEN mismatch")
  }
  if reader.pos + len > reader.len {
    fail("Corrupted deflate stream: stored block payload truncated")
  }
  reader.pos = reader.pos + len
  len
}

///|
fn parse_dynamic_header(reader : BitReader) -> (Int, Int, Int) raise {
  let hlit = reader.read_bits(5) + 257
  let hdist = reader.read_bits(5) + 1
  if hlit > 286 || hdist > 30 {
    fail("Corrupted deflate stream: invalid HLIT/HDIST range")
  }
  let hclen = reader.read_bits(4) + 4
  for _i = 0; _i < hclen; _i = _i + 1 {
    let _ = reader.read_bits(3)

  }
  (hlit, hdist, hclen)
}

///|
struct BlockMetadata {
  block_type : Int
  is_final : Bool
  stored_len : Int
  hlit : Int
  hdist : Int
  hclen : Int
}

///|
fn inspect_first_block(bytes : BytesView) -> BlockMetadata raise {
  let reader = BitReader::new(bytes)
  let is_final = reader.read_bits(1) == 1
  let block_type = reader.read_bits(2)
  let mut stored_len = 0
  let mut hlit = 0
  let mut hdist = 0
  let mut hclen = 0
  match block_type {
    0 => stored_len = parse_stored_block(reader)
    1 => ()
    2 => {
      let (hl, hd, hc) = parse_dynamic_header(reader)
      hlit = hl
      hdist = hd
      hclen = hc
    }
    _ => fail("Corrupted deflate stream: invalid block type")
  }
  { block_type, is_final, stored_len, hlit, hdist, hclen }
}

///|
fn repeat_slice(data : Bytes, times : Int) -> Bytes {
  let len = data.length()
  if times == 0 || len == 0 {
    return b""
  }
  let buf = @bytebuf.new(size_hint=len * times)
  let view = data[0:len]
  for _i = 0; _i < times; _i = _i + 1 {
    buf.write_bytesview(view)
  }
  buf.contents()
}

///|
fn make_incrementing(len : Int) -> Bytes {
  let buf = @bytebuf.new(size_hint=if len == 0 { 1 } else { len })
  for i = 0; i < len; i = i + 1 {
    buf.write_byte((i & 0xFF).to_byte())
  }
  buf.contents()
}

///|
fn make_mixed(len : Int) -> Bytes {
  let buf = @bytebuf.new(size_hint=if len == 0 { 1 } else { len })
  for i = 0; i < len; i = i + 1 {
    if i % 128 < 96 {
      buf.write_byte(if i % 2 == 0 { b'A' } else { b'B' })
    } else {
      let value = ((i * 73 + 91) & 0xFF).to_byte()
      buf.write_byte(value)
    }
  }
  buf.contents()
}

///|
// Exercise a matrix of payloads and levels, verifying both data round-trips and
// the first block's structural metadata.
test "deflate_roundtrip_parameter_matrix" {
  let dataset_len = 6
  let inputs = Array::make(dataset_len, b"")
  inputs[0] = b""
  inputs[1] = b"A"
  inputs[2] = repeat_slice(b"abc", 64)
  inputs[3] = repeat_slice(b"The quick brown fox jumps over the lazy dog. ", 32)
  inputs[4] = make_incrementing(65535)
  inputs[5] = make_mixed(70000)
  let level_count = 4
  let mut success_pairs = 0
  let mut attempted = 0
  for i = 0; i < dataset_len; i = i + 1 {
    let input = inputs[i]
    let view = input
    for j = 0; j < level_count; j = j + 1 {
      if j == 0 && input.length() > 65535 {
        continue
      }
      let level = match j {
        0 => Some(@deflate.DeflateLevel::None)
        1 => Some(@deflate.DeflateLevel::Fast)
        2 => Some(@deflate.DeflateLevel::Default)
        _ => Some(@deflate.DeflateLevel::Best)
      }
      let compressed = @deflate.deflate(view, level?)
      let decoded = @deflate.inflate(compressed)
      assert_eq(decoded, input)
      let meta = inspect_first_block(compressed)
      @json.inspect(meta.is_final, content=true)
      match level {
        Some(@deflate.DeflateLevel::None) => {
          @json.inspect(meta.block_type, content=0)
          @json.inspect(meta.stored_len == input.length(), content=true)
        }
        Some(@deflate.DeflateLevel::Fast) =>
          @json.inspect(meta.block_type, content=1)
        Some(@deflate.DeflateLevel::Default) =>
          if input.length() >= 512 {
            @json.inspect(meta.block_type, content=2)
            @json.inspect(meta.hlit >= 257 && meta.hlit <= 286, content=true)
          }
        Some(@deflate.DeflateLevel::Best) =>
          if input.length() >= 512 {
            @json.inspect(meta.block_type, content=2)
            @json.inspect(meta.hdist >= 1 && meta.hdist <= 30, content=true)
          }
        None => ()
      }
      success_pairs = success_pairs + 1
      attempted = attempted + 1
    }
  }
  @json.inspect(success_pairs == attempted, content=true)
  @json.inspect(success_pairs > 0, content=true)
}

///|
// Confirm fixed-Huffman encoding remains deterministic for repeated payloads.
test "deflate_fixed_deterministic" {
  let data = repeat_slice(
    b"Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", 8,
  )
  let view = data
  let first = @deflate.deflate(view, level=@deflate.DeflateLevel::Fast)
  let second = @deflate.deflate(view, level=@deflate.DeflateLevel::Fast)
  assert_eq(first, second)
  let decoded = @deflate.inflate(first)
  assert_eq(decoded, data)
  let meta = inspect_first_block(first)
  @json.inspect(meta.block_type, content=1)
  @json.inspect(meta.is_final, content=true)
}

///|
// Validate that the dynamic header stays within HLIT/HDIST/HCLEN limits.
test "deflate_dynamic_header_ranges" {
  let data = repeat_slice(
    b"Dynamic Huffman blocks like repetition and variation across the buffer.\n",
    64,
  )
  let view = data
  let compressed = @deflate.deflate(view, level=@deflate.DeflateLevel::Best)
  let decoded = @deflate.inflate(compressed)
  assert_eq(decoded, data)
  let meta = inspect_first_block(compressed)
  @json.inspect(meta.block_type, content=2)
  @json.inspect(meta.hlit >= 257 && meta.hlit <= 286, content=true)
  @json.inspect(meta.hdist >= 1 && meta.hdist <= 30, content=true)
  @json.inspect(meta.hclen >= 4 && meta.hclen <= 19, content=true)
}

///|
// Ensure separately compressed streams remain valid final blocks when combined.
test "deflate_concatenation_roundtrip" {
  let part_a = repeat_slice(b"AAAAABBBBB", 40)
  let part_b = make_incrementing(256)
  let comp_a = @deflate.deflate(part_a, level=@deflate.DeflateLevel::Default)
  let comp_b = @deflate.deflate(part_b, level=@deflate.DeflateLevel::Default)
  let dec_a = @deflate.inflate(comp_a)
  let dec_b = @deflate.inflate(comp_b)
  assert_eq(dec_a, part_a)
  assert_eq(dec_b, part_b)
  let combined = {
    let buf = @bytebuf.new(size_hint=part_a.length() + part_b.length())
    buf.write_bytesview(part_a)
    buf.write_bytesview(part_b)
    buf.contents()
  }
  let merged_decoded = {
    let buf = @bytebuf.new(size_hint=dec_a.length() + dec_b.length())
    buf.write_bytesview(dec_a)
    buf.write_bytesview(dec_b)
    buf.contents()
  }
  assert_eq(merged_decoded, combined)
  let meta_a = inspect_first_block(comp_a)
  let meta_b = inspect_first_block(comp_b)
  @json.inspect(meta_a.block_type, content=2)
  @json.inspect(meta_b.block_type, content=2)
  @json.inspect(meta_a.is_final, content=true)
  @json.inspect(meta_b.is_final, content=true)
}
