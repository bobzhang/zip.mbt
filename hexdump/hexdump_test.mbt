// Tests for hexdump utility functions

///|
/// Hex dump utility tests
test "hex_dump_empty" {
  let empty_data = b""
  let result = @hexdump.hex_dump(empty_data)
  @json.inspect(result, content="")
}

///|
test "hex_dump_single_byte" {
  let data = Bytes::from_array([0x41]) // 'A'
  let result = @hexdump.hex_dump(data)
  @json.inspect(
    result,
    content="00000000  41                                                 |A|\n",
  )
}

///|
test "hex_dump_short_string" {
  let data = b"Hello"
  let result = @hexdump.hex_dump(data)
  @json.inspect(
    result,
    content="00000000  48 65 6c 6c 6f                                     |Hello|\n",
  )
}

///|
test "hex_dump_exactly_16_bytes" {
  let data = b"1234567890abcdef"
  let result = @hexdump.hex_dump(data)
  @json.inspect(
    result,
    content="00000000  31 32 33 34 35 36 37 38  39 30 61 62 63 64 65 66   |1234567890abcdef|\n",
  )
}

///|
test "hex_dump_17_bytes" {
  let data = b"1234567890abcdefg"
  let result = @hexdump.hex_dump(data)
  @json.inspect(
    result,
    content="00000000  31 32 33 34 35 36 37 38  39 30 61 62 63 64 65 66   |1234567890abcdef|\n00000010  67                                                 |g|\n",
  )
}

///|
test "hex_dump_mixed_printable_nonprintable" {
  let data = Bytes::from_array([
    0x48, 0x65, 0x6c, 0x6c, 0x6f, // "Hello"
     0x00, 0x01, 0x02, 0x03, 0x04, // Non-printable bytes
     0x20, 0x21, 0x22, 0x23, 0x24, // Printable ASCII
     0x7f, 0x80, 0xff, // More non-printable
  ])
  let result = @hexdump.hex_dump(data)
  @json.inspect(
    result,
    content="00000000  48 65 6c 6c 6f 00 01 02  03 04 20 21 22 23 24 7f   |Hello..... !\"#$.|\n00000010  80 ff                                              |..|\n",
  )
}

///|
test "hex_dump_zip_magic_signature" {
  // Test with ZIP file magic signature "PK\x03\x04"
  let data = Bytes::from_array([0x50, 0x4B, 0x03, 0x04])
  let result = @hexdump.hex_dump(data)
  @json.inspect(
    result,
    content="00000000  50 4b 03 04                                        |PK..|\n",
  )
}

///|
test "hex_dump_all_hex_digits" {
  // Test with all possible hex digit combinations
  let data = Bytes::from_array([
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c,
    0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19,
    0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
  ])
  let result = @hexdump.hex_dump(data)
  @json.inspect(
    result,
    content="00000000  00 01 02 03 04 05 06 07  08 09 0a 0b 0c 0d 0e 0f   |................|\n00000010  10 11 12 13 14 15 16 17  18 19 1a 1b 1c 1d 1e 1f   |................|\n",
  )
}

///|
test "hex_dump_32_bytes_multiple_lines" {
  // Test with exactly 32 bytes to get 2 full lines
  let data = Bytes::from_array([
    0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d,
    0x4e, 0x4f, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a,
    0x61, 0x62, 0x63, 0x64, 0x65, 0x66,
  ])
  let result = @hexdump.hex_dump(data)
  @json.inspect(
    result,
    content="00000000  41 42 43 44 45 46 47 48  49 4a 4b 4c 4d 4e 4f 50   |ABCDEFGHIJKLMNOP|\n00000010  51 52 53 54 55 56 57 58  59 5a 61 62 63 64 65 66   |QRSTUVWXYZabcdef|\n",
  )
}

///|
test "hex_dump_real_zip_file_header" {
  // Test with actual ZIP file header from our test file
  let data = Bytes::from_array([
    0x50, 0x4B, 0x03, 0x04, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3D, 0x89, 0x41,
    0x5B, 0x54, 0x2A,
  ])
  let result = @hexdump.hex_dump(data)
  @json.inspect(
    result,
    content="00000000  50 4b 03 04 0a 00 00 00  00 00 3d 89 41 5b 54 2a   |PK........=.A[T*|\n",
  )
}
