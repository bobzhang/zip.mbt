// Hex dump utility functions for MoonBit
// Provides hex dump functionality similar to hexdump -C command

///|
/// Convert bytes to a hex dump format similar to hexdump -C
/// Shows offset, hex bytes, and ASCII representation
pub fn hex_dump(data : Bytes) -> String {
  let mut result = ""
  let mut offset = 0
  while offset < data.length() {
    // Format offset (8 hex digits)
    let offset_str = format_offset(offset)
    result = result + offset_str + "  "

    // Format hex bytes (16 bytes per line, 2 chars per byte + spaces)
    let hex_str = format_hex_bytes(data, offset)
    result = result + hex_str + "  "

    // Format ASCII representation
    let ascii_str = format_ascii_bytes(data, offset)
    result = result + "|" + ascii_str + "|\n"
    offset = offset + 16
  }
  result
}

///|
/// Format offset as 8-digit hex string
fn format_offset(offset : Int) -> String {
  let hex_digits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let mut result = ""
  let mut val = offset

  // Generate 8 hex digits
  for i = 0; i < 8; i = i + 1 {
    let digit = val & 0xF
    result = Char::to_string(hex_digits[digit]) + result
    val = val >> 4
  }
  result
}

///|
/// Format bytes as hex string (16 bytes per line)
fn format_hex_bytes(data : Bytes, start_offset : Int) -> String {
  let mut result = ""
  let mut pos = start_offset

  // Process 16 bytes per line
  for i = 0; i < 16; i = i + 1 {
    if pos < data.length() {
      let byte_val = data[pos].to_int()
      let hex_digits = [
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e',
        'f',
      ]
      let high_nibble = (byte_val >> 4) & 0xF
      let low_nibble = byte_val & 0xF
      result = result +
        Char::to_string(hex_digits[high_nibble]) +
        Char::to_string(hex_digits[low_nibble])
    } else {
      result = result + "  " // Pad with spaces for incomplete lines
    }

    // Add space between bytes (except after 8th byte, add extra space)
    if i == 7 {
      result = result + "  "
    } else {
      result = result + " "
    }
    pos = pos + 1
  }
  result
}

///|
/// Format bytes as ASCII representation (16 bytes per line)
fn format_ascii_bytes(data : Bytes, start_offset : Int) -> String {
  let mut result = ""
  let mut pos = start_offset

  // Process 16 bytes per line
  for i = 0; i < 16 && pos < data.length(); i = i + 1 {
    let byte_val = data[pos].to_int()
    let char_val = if byte_val >= 32 && byte_val <= 126 {
      // Printable ASCII character
      byte_val.to_byte().to_char()
    } else {
      // Non-printable character, show as '.'
      '.'
    }
    result = result + Char::to_string(char_val)
    pos = pos + 1
  }
  result
}
