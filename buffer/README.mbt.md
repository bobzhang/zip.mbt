# buffer - Dynamic Byte Buffer

**Level**: 0 (no dependencies)  
**Package**: `bobzhang/zip/buffer`

## Overview

The `buffer` package provides `ByteBuf`, a growable byte buffer for efficient byte-by-byte and chunk assembly. It's designed for building binary data structures where the final size isn't known upfront.

## Features

- **Dynamic Growth**: Automatically grows as needed
- **Efficient Operations**: Add single bytes or byte ranges
- **Copy-Back Support**: Efficiently copy from earlier positions (for LZ77 decompression)
- **Flexible Construction**: Create with fixed or growable size

## API

### Types



A mutable, growable byte buffer.

### Functions

#### `ByteBuf::new(size : Int, exact : Bool) -> ByteBuf`

Create a new byte buffer.
- If `exact` is true, allocates exactly `size` bytes (non-growable)
- If `exact` is false, treats `size` as initial capacity (will grow if needed)

#### `add_byte(self : ByteBuf, byte : Int) -> Unit`

Append a single byte to the buffer.

#### `add_bytes(self : ByteBuf, src : Bytes, start : Int, len : Int) -> Unit`

Append a range of bytes from a source buffer.

#### `recopy(self : ByteBuf, back_offset : Int, length : Int) -> Unit`

Copy bytes from an earlier position in the buffer to the end.  
Used for LZ77 decompression to expand back-references.

#### `length(self : ByteBuf) -> Int`

Get the current number of bytes in the buffer.

#### `contents(self : ByteBuf) -> Bytes`

Get the buffer contents as immutable `Bytes`.

## Usage Example

```moonbit
///|
test {
  let buf = ByteBuf::new(100, fixed=false) // Initial capacity 100, growable
  buf.write_byte(0x50)
  buf.write_byte(0x4B)
  let data = b"test data!"
  buf.write_bytes(data, 0, 10)
  buf.recopy(0, 2) // Copy first 2 bytes to end
  let result = buf.contents()
  @json.inspect(result.length(), content=14)
  @json.inspect((result[0].to_int(), result[1].to_int()), content=[80, 75])
}
```

## Implementation Notes

- Uses `Array[Byte]` internally for the mutable buffer
- Growth strategy: doubles capacity when needed
- `recopy` handles overlapping copies correctly for LZ77 patterns
- Final `contents()` creates an immutable `Bytes` copy

## Dependencies

None - This is a Level 0 package.

## Used By

- `deflate` - For building compressed output
- `bitstream` - For assembling bit-packed data
- Main `zip` package - For general byte assembly

## Testing

Run tests with:
```bash
moon test buffer
```

Tests cover:
- Basic byte addition
- Dynamic growth
- Copy-back operations
- Edge cases for buffer management
