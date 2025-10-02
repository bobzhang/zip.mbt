# bitstream - Bit-Level I/O

**Level**: 1  
**Package**: `bobzhang/zip/bitstream`  
**Dependencies**: `buffer`

## Overview

The `bitstream` package provides `BitWriter` for writing data at the bit level, essential for DEFLATE compression where symbols have variable bit lengths. It handles bit packing, byte alignment, and efficient buffering.

## Features

- **Bit-Level Writing**: Write 1-32 bits at a time
- **Little-Endian**: LSB-first bit order (DEFLATE standard)
- **Byte Buffering**: Automatic byte boundary management
- **Flush Support**: Align to byte boundaries when needed
- **Efficient**: Minimal overhead for variable-length codes

## API

### Types

```moonbit
pub struct BitWriter
```

A bit-level output writer backed by a `ByteBuf`.

### Functions

#### `BitWriter::new(output : ByteBuf) -> BitWriter`

Create a new bit writer.

**Parameters:**
- `output` - ByteBuf to write bytes to

#### `write_bits(self : BitWriter, bits : Int, count : Int) -> Unit`

Write up to 32 bits to the stream.

**Parameters:**
- `bits` - The bit pattern to write
- `count` - Number of bits to write (1-32)

**Behavior:**
- Bits are written LSB-first (little-endian bit order)
- Accumulates bits in a buffer until 8+ bits available
- Writes complete bytes to the underlying ByteBuf

#### `flush(self : BitWriter) -> Unit`

Flush any pending bits to the output buffer.

If there are partial bits (< 8), pads with zeros to reach a byte boundary.

## Usage Example

```moonbit
let output = ByteBuf::new(100, false)
let writer = BitWriter::new(output)

// Write a 3-bit value
writer.write_bits(0b101, 3)  // Writes: 101

// Write a 5-bit value
writer.write_bits(0b11010, 5)  // Writes: 11010

// At this point, 8 bits written, one byte flushed to ByteBuf: 0b01011101

// Write more bits
writer.write_bits(0xFF, 7)  // Writes: 1111111

// Flush remaining bits (pads to byte boundary)
writer.flush()

let result = output.contents()
```

## Bit Order

DEFLATE uses **LSB-first** (little-endian) bit order:

```moonbit
write_bits(0b110, 3)  // Writes bits: 0, 1, 1 (right to left)
```

Example: Writing Huffman codes
```moonbit
// Fixed Huffman code for 'A' (65): code=00110000 (8 bits)
writer.write_bits(0b00110000, 8)

// Code length symbol: code=101 (3 bits)  
writer.write_bits(0b101, 3)
```

## Internal State

The writer maintains:
- `buffer: Int` - Bit accumulation buffer (up to 32 bits)
- `buffer_len: Int` - Number of valid bits in buffer
- `output: ByteBuf` - Underlying byte buffer

When `buffer_len >= 8`, the LSB byte is written to output and removed from buffer.

## Real-World Usage

### DEFLATE Block Header

```moonbit
// Write block header: BFINAL=1, BTYPE=01 (fixed Huffman)
let header = 0b011  // 1 (final), 01 (fixed)
writer.write_bits(header, 3)
```

### Huffman Encoding

```moonbit
// Write a Huffman code
let code = 0b00110000  // 8-bit code
let code_len = 8
writer.write_bits(code, code_len)

// Write extra bits for length
writer.write_bits(extra_bits, extra_count)
```

### Dynamic Huffman Header

```moonbit
// RFC 1951 dynamic block header
writer.write_bits(hlit, 5)    // # of literal codes - 257
writer.write_bits(hdist, 5)   // # of distance codes - 1
writer.write_bits(hclen, 4)   // # of code length codes - 4

// Code length code lengths (3 bits each)
for i = 0; i < hclen + 4; i = i + 1 {
  writer.write_bits(codelen_lengths[i], 3)
}
```

## Performance

- **Time Complexity**: O(1) per `write_bits` call (amortized)
- **Space Complexity**: O(1) additional space (32-bit buffer)
- **Efficiency**: Batches bits into bytes before writing
- **No Allocation**: Uses existing ByteBuf, no new allocations

## Edge Cases

- **Zero bits**: `write_bits(_, 0)` is a no-op
- **Flush with empty buffer**: No bytes written
- **Flush with partial bits**: Pads with 0s to byte boundary
- **32-bit writes**: Handles maximum bit count correctly

## Testing

Run tests with:
```bash
moon test bitstream
```

Tests cover:
- Basic bit writing
- Byte boundary alignment
- Flush operations
- LSB-first bit order
- Multiple sequential writes
- Various bit counts (1-32 bits)

## Dependencies

- `buffer` (Level 0) - For underlying byte storage

## Used By

- `deflate` (Level 2) - For writing compressed DEFLATE streams
- Main `zip` package - Via deflate re-exports

## Implementation Notes

- Uses standard bit packing: `buffer |= (bits << buffer_len)`
- Efficient byte extraction: `(buffer & 0xFF).to_byte()`
- Bit shift for buffer maintenance: `buffer >> 8`
- Flush pads with zeros, never truncates bits

## Standards Compliance

Implements bit-level writing as required by:
- RFC 1951 (DEFLATE Compressed Data Format)
- LSB-first (little-endian) bit order per DEFLATE spec
