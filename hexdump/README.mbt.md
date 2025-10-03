# hexdump - Hex Dump Utility

**Level**: 0 (no dependencies)  
**Package**: `bobzhang/zip/hexdump`

## Overview

The `hexdump` package provides utilities for formatting binary data as hexadecimal dumps, similar to the Unix `hexdump` command. Useful for debugging and visualizing binary data structures.

## Features

- **Classic Hex Dump Format**: Address, hex bytes, ASCII representation
- **Flexible Range**: Dump entire buffer or specific range
- **Readable Output**: 16 bytes per line with ASCII display
- **Non-Printable Handling**: Shows `.` for non-ASCII characters

## API

### Functions

#### `hexdump(data : Bytes) -> String`

Create a hex dump of the entire byte array.

**Parameters:**
- `data` - Byte array to dump

**Returns:** Multi-line string with hex dump format

#### `hexdump_range(data : Bytes, start : Int, len : Int) -> String`

Create a hex dump of a byte range.

**Parameters:**
- `data` - Source byte array
- `start` - Starting offset
- `len` - Number of bytes to dump

**Returns:** Multi-line string with hex dump format

## Output Format

Each line shows:
```
OFFSET: HH HH HH HH HH HH HH HH HH HH HH HH HH HH HH HH  |ASCII........... |
```

Where:
- `OFFSET` - 8-digit hexadecimal offset from start
- `HH` - Hexadecimal byte values (16 per line)
- `ASCII` - ASCII representation (`.` for non-printable chars)

## Usage Example

```moonbit
test {
  let data = b"Hello, World!\x00\x01\x02"

  // Dump entire buffer
  let output = hex_dump(data)
  @json.inspect(output.contains("48 65 6c 6c 6f"), content=true)
  @json.inspect(output.contains("Hello, World!"), content=true)
}
```

## Real-World Usage

```
// Debug ZIP file headers
let zip_header = read_file_header(data, pos)
println("ZIP Local File Header:")
println(hex_dump_range(data, pos, 30))

// Debug compressed data
println("First 128 bytes of compressed data:")
println(hex_dump_range(compressed, 0, 128))

// Inspect DEFLATE blocks
println("DEFLATE block header:")
println(hex_dump_range(deflated, block_start, 16))
```

## Implementation Details

- **Address Display**: 8-digit hex addresses (supports files up to 4GB)
- **Byte Grouping**: 16 bytes per line for readability
- **ASCII Threshold**: Displays ASCII characters 32-126, others as `.`
- **Short Lines**: Properly handles final line with < 16 bytes
- **Efficient**: Uses `StringBuilder` for string concatenation

## Performance

- **Time Complexity**: O(n) where n is the number of bytes
- **Space Complexity**: O(n) for the output string
- **Memory**: Allocates string buffer for output

## Common Use Cases

1. **Debugging Binary Formats**
   ```
   println("Unexpected bytes at offset \{offset}:")
   println(hex_dump_range(data, offset - 16, 48))
   ```

2. **Validating File Structures**
   ```
   println("ZIP signature check:")
   println(hex_dump_range(file_data, 0, 4))
   // Should show: 50 4B 03 04 (PK..)
   ```

3. **Comparing Binary Data**
   ```
   println("Original:")
   println(hex_dump(original))
   println("Decompressed:")
   println(hex_dump(decompressed))
   ```

4. **Test Output**
   ```
   test "deflate compression" {
     let compressed = deflate(data)
     println("Compressed output:")
     println(hex_dump(compressed))
     // Visual verification of compression format
   }
   ```

## Testing

Run tests with:
```bash
moon test hexdump
```

Tests cover:
- Empty data
- Single byte
- Full 16-byte line
- Multiple lines
- Partial final line
- Non-ASCII characters
- All byte values (0x00-0xFF)

## Dependencies

None - This is a Level 0 package.

## Used By

- Main `zip` package (test-import) - For debugging in tests
- Development/debugging - Not used in production code

## Notes

- This package is typically imported only for tests (`test-import`)
- Output format matches traditional `hexdump` tools for familiarity
- Great for generating reproducible test outputs
