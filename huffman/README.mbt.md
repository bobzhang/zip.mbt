# huffman - Huffman Coding

**Level**: 1  
**Package**: `bobzhang/zip/huffman`  
**Dependencies**: None

## Overview

The `huffman` package implements Huffman encoding and decoding for DEFLATE compression (RFC 1951). It provides both fixed and dynamic Huffman trees, canonical Huffman code generation, and efficient symbol lookup.

## Features

- **Fixed Huffman Codes**: Pre-built trees for DEFLATE fixed blocks
- **Dynamic Huffman**: Build custom trees from symbol lengths
- **Canonical Huffman**: Generates RFC 1951 compliant codes
- **Efficient Decoding**: Fast tree-based symbol lookup
- **Encoding Support**: Symbol-to-code mapping for compression

## API

### Types

#### `HuffmanDecoder`

```
pub struct HuffmanDecoder {
  pub counts : Array[Int]    // counts[i] = # of codes with length i
  pub symbols : Array[Int]   // Symbols sorted by code
  pub mut max_sym : Int      // Maximum symbol value
}
```

Decodes Huffman-encoded symbols.

#### `HuffmanEncoder`

```
pub struct HuffmanEncoder {
  pub codes : Array[SymInfo]  // codes[symbol] = (code, length)
  pub mut max_sym : Int       // Maximum encoded symbol
}
```

Encodes symbols to Huffman codes.

#### `SymInfo`

```
pub typealias Int as SymInfo
```

Packed representation: `(code << 16) | code_length`

### Constants

#### Fixed Huffman Trees

```
pub let fixed_litlen_decoder : HuffmanDecoder
pub let fixed_dist_decoder : HuffmanDecoder
pub let fixed_litlen_encoder : HuffmanEncoder
pub let fixed_dist_encoder : HuffmanEncoder
```

Pre-built trees for DEFLATE fixed Huffman blocks.

### Functions

#### Decoder Functions

##### `HuffmanDecoder::new() -> HuffmanDecoder`

Create an empty Huffman decoder.

##### `init_from_lengths(self, lengths : Array[Int], start : Int, count : Int) -> Unit`

Initialize decoder from code lengths.

**Parameters:**
- `lengths` - Array of code lengths for each symbol
- `start` - Starting index in lengths array
- `count` - Number of symbols

**RFC 1951 Algorithm:**
1. Count codes of each length
2. Compute first code for each length (canonical)
3. Assign codes to symbols in order

#### Encoder Functions

##### `HuffmanEncoder::new() -> HuffmanEncoder`

Create an empty Huffman encoder.

##### `get(self, symbol : Int) -> SymInfo`

Get encoding information for a symbol.

##### `set(self, symbol : Int, info : SymInfo) -> Unit`

Set encoding information for a symbol.

#### Symbol Info Functions

```
pub fn sym_info_make(code : Int, code_length : Int) -> SymInfo
pub fn sym_info_code(info : SymInfo) -> Int
pub fn sym_info_code_length(info : SymInfo) -> Int
```

Pack/unpack symbol encoding information.

#### Utility

##### `reverse_bits(value : Int, length : Int) -> Int`

Reverse bit order (for canonical Huffman codes).

## Fixed Huffman Codes (RFC 1951)

### Literal/Length Codes

| Symbol Range | Code Length | Code Pattern |
|--------------|-------------|--------------|
| 0-143 | 8 bits | 00110000 - 10111111 |
| 144-255 | 9 bits | 110010000 - 111111111 |
| 256-279 | 7 bits | 0000000 - 0010111 |
| 280-287 | 8 bits | 11000000 - 11000111 |

### Distance Codes

| Symbol Range | Code Length |
|--------------|-------------|
| 0-31 | 5 bits |

## Usage Example

### Decoding

```
// Initialize from code lengths
let decoder = HuffmanDecoder::new()
let lengths = [8, 8, 8, 7, 7, 9]  // Code lengths for symbols 0-5
decoder.init_from_lengths(lengths, 0, 6)

// Use with bit stream (in deflate decoder)
let symbol = decoder.read_symbol(bit_stream)
```

### Encoding

```
// Build encoder from code lengths
let encoder = HuffmanEncoder::new()
for i = 0; i < symbol_count; i = i + 1 {
  let code = compute_canonical_code(lengths[i], i)
  encoder.set(i, sym_info_make(code, lengths[i]))
}

// Encode a symbol
let info = encoder.get(symbol)
let code = sym_info_code(info)
let length = sym_info_code_length(info)
bit_writer.write_bits(code, length)
```

### Building Canonical Huffman

```
// From frequency counts, build optimal code lengths
let lengths = build_optimal_code_lengths(frequencies, max_symbol, 15)

// Convert to canonical Huffman codes
let next_code = Array::make(16, 0)
let mut code = 0
for len = 1; len <= 15; len = len + 1 {
  code = (code + count[len - 1]) << 1
  next_code[len] = code
}

// Assign codes to symbols
for sym = 0; sym <= max_symbol; sym = sym + 1 {
  let len = lengths[sym]
  if len > 0 {
    let c = next_code[len]
    let bits = reverse_bits(c, len)
    encoder.set(sym, sym_info_make(bits, len))
    next_code[len] = c + 1
  }
}
```

## Performance

### Decoder
- **Initialization**: O(n + k) where n = # symbols, k = max code length
- **Symbol Lookup**: O(k) where k = code length (typically ≤ 15)
- **Memory**: O(n + k) for counts and symbols arrays

### Encoder
- **Lookup**: O(1) - direct array access
- **Memory**: O(n) where n = alphabet size (typically 286 or 30)

## Algorithm Details

### Canonical Huffman Construction

1. **Count codes of each length**
   ```
   count[len] = number of symbols with code length 'len'
   ```

2. **Compute first code for each length**
   ```
   code[len] = (code[len-1] + count[len-1]) << 1
   ```

3. **Assign codes sequentially**
   ```
   for each symbol with length 'len':
     code[sym] = next_code[len]++
   ```

4. **Reverse bits** (for LSB-first bit order)

### Symbol Decoding

Uses a level-by-level tree walk:
```
fn read_symbol(decoder, bit_stream):
  len = 1, base = 0, offs = 0
  loop:
    offs = 2 * offs + read_bit()
    if offs < counts[len]:
      return symbols[base + offs]
    offs -= counts[len]
    base += counts[len]
    len += 1
```

## Testing

Run tests with:
```bash
moon test huffman
```

Tests cover:
- Fixed Huffman tree initialization
- Dynamic tree construction
- Canonical code generation
- Symbol encoding/decoding
- Edge cases (single symbol, empty tree)
- Bit reversal

## Dependencies

None - This is a Level 1 package with no external dependencies.

## Used By

- `deflate` (Level 2) - For DEFLATE compression/decompression
- `lz77` (Level 1) - Indirectly via deflate
- Main `zip` package - Via deflate re-exports

## Standards Compliance

Implements Huffman coding as specified in:
- **RFC 1951** - DEFLATE Compressed Data Format Specification
  - Section 3.2.2: Fixed Huffman codes
  - Section 3.2.3: Dynamic Huffman codes
  - Section 3.2.7: Code length encoding

## Implementation Notes

- **Canonical Huffman**: Ensures deterministic encoding/decoding
- **Bit Reversal**: Required for LSB-first bit order in DEFLATE
- **Zero-Length Codes**: Properly handled (symbol not in tree)
- **Maximum Code Length**: RFC 1951 limits to 15 bits for literals, 15 for distances
- **Empty Trees**: Handled gracefully (max_sym = -1)

## References

- [RFC 1951 - DEFLATE Specification](https://www.rfc-editor.org/rfc/rfc1951)
- Huffman, David A. (1952). "A Method for the Construction of Minimum-Redundancy Codes"
