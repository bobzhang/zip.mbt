# lz77 - LZ77 String Matching

**Level**: 1  
**Package**: `bobzhang/zip/lz77`  
**Dependencies**: None

## Overview

The `lz77` package implements the LZ77 sliding window compression algorithm, which finds repeated strings in data and replaces them with back-references. This is the core string matching component of DEFLATE compression.

## Features

- **Sliding Window**: 32KB window for finding matches
- **Hash Chain Search**: Fast O(1) hash insertion, O(n) match search
- **Lazy Matching**: Defers encoding to find better matches
- **Configurable Parameters**: Adjust quality vs. speed tradeoffs
- **Match Length 3-258**: DEFLATE specification compliant
- **Distance 1-32768**: Full window support

## Algorithm

LZ77 replaces repeated byte sequences with (length, distance) pairs:

```
Input:  "The quick brown fox jumps over the lazy dog. The quick brown fox..."
Output: "The quick brown fox jumps over the lazy dog. [49 bytes back, 19 bytes]..."
```

## API

### Constants

```
pub let min_match_len : Int = 3        // Minimum match length
pub let max_match_len : Int = 258      // Maximum match length  
pub let max_match_dist : Int = 32768   // Maximum back-reference distance
pub let window_size : Int = 32768      // Sliding window size
pub let hash_bit_size : Int = 15       // Hash table size (2^15)
pub let hash_size : Int = 32768        // Hash table entries
pub let no_pos : Int = -1              // Marker for "no position"
```

### Functions

#### Hash Functions

##### `hash4(bytes : Bytes, i : Int) -> Int`

Compute 4-byte rolling hash at position i.

**Hash Function:**
```
hash = (b[i] + (b[i+1] << 5) + (b[i+2] << 10) + (b[i+3] << 15)) & 0x7FFF
```

##### `insert_hash(hash_head : Array[Int], hash_prev : Array[Int], hash : Int, pos : Int) -> Unit`

Insert position into hash chain.

**Parameters:**
- `hash_head[hash]` - Most recent position for this hash
- `hash_prev[pos]` - Previous position in chain
- `hash` - Hash value
- `pos` - Current position to insert

#### Matching Functions

##### `match_fwd(bytes : Bytes, i : Int, j : Int, len : Int, max_match_len : Int) -> Int`

Extend a match forward from position i and j, starting with known length.

**Returns:** Final match length

##### `find_match_length(bytes : Bytes, i : Int, j : Int, prev_match_len : Int, max_match_len : Int) -> Int`

Find match length between positions i and j, only if it beats previous match.

**Returns:** Match length or 0 if not better than previous

##### `find_backref(bytes, hash_head, hash_prev, pos, hash, prev_match_len, max_match_len, good_match, max_chain_len) -> Int`

Search hash chain for the best match at current position.

**Parameters:**
- `pos` - Current position in input
- `hash` - Hash value at current position
- `prev_match_len` - Length of previous match (lazy matching)
- `max_match_len` - Maximum match length possible
- `good_match` - "Good enough" match length (stop early)
- `max_chain_len` - Maximum hash chain entries to check

**Returns:** Packed back-reference (dist << 16 | len) or 0 if no match

#### Back-Reference Encoding

##### `make_backref(dist : Int, len : Int) -> Int`

Pack distance and length into a single integer.

**Format:** `(dist << 16) | len`

##### `backref_dist(bref : Int) -> Int`

Extract distance from packed back-reference.

**Returns:** `bref >> 16`

##### `backref_len(bref : Int) -> Int`

Extract length from packed back-reference.

**Returns:** `bref & 0xFFFF`

## Usage Example

### Basic Compression

```
// Initialize hash tables
let hash_head = Array::make(lz77_hash_size, lz77_no_pos)
let hash_prev = Array::make(lz77_window_size, 0)

// Compression parameters
let good_match = 8     // Good enough match length
let max_chain = 1024   // Hash chain depth

// Compress loop
for pos = start; pos < start + len - min_match_len; pos = pos + 1 {
  // Compute hash at current position
  let hash = hash4(bytes, pos)
  
  // Find best match
  let max_match = (start + len - pos).min(max_match_len)
  let bref = find_backref(
    bytes, hash_head, hash_prev, pos, hash,
    0, max_match, good_match, max_chain
  )
  
  // Insert into hash
  insert_hash(hash_head, hash_prev, hash, pos)
  
  // Output match or literal
  if backref_len(bref) >= min_match_len {
    output_match(backref_len(bref), backref_dist(bref))
    pos += backref_len(bref) - 1
  } else {
    output_literal(bytes[pos])
  }
}
```

### Lazy Matching

```
let mut prev_bref = 0

for pos = start; pos < end; pos = pos + 1 {
  let cur_bref = find_backref(...)
  
  if backref_len(prev_bref) > 0 && 
     backref_len(prev_bref) >= backref_len(cur_bref) {
    // Previous match was better, use it
    output_match(backref_len(prev_bref), backref_dist(prev_bref))
    pos += backref_len(prev_bref) - 1
    prev_bref = 0
  } else if backref_len(cur_bref) >= min_match_len {
    // Found a match, defer decision
    output_literal(bytes[pos - 1])
    prev_bref = cur_bref
  } else {
    // No match
    output_literal(bytes[pos])
    prev_bref = 0
  }
}
```

## Performance Tuning

### Compression Levels

**Fast (Level 1):**
```
good_match = 4
max_chain = 128
```
- Quick compression
- Lower compression ratio
- Good for real-time or streaming

**Default (Level 6):**
```
good_match = 8
max_chain = 1024
```
- Balanced speed and compression
- Good general-purpose setting

**Best (Level 9):**
```
good_match = 32
max_chain = 4096
```
- Maximum compression
- Slower compression speed
- Best for archival or bandwidth-sensitive applications

### Parameters Explained

- **`good_match`**: Stop searching if match ≥ this length
  - Higher = better compression, slower
  - Lower = faster, less compression

- **`max_chain`**: Maximum hash chain entries to check
  - Higher = more thorough search, slower
  - Lower = faster, may miss best matches

## Algorithm Details

### Hash Table Structure

```
hash_head[hash] → most recent position with this hash
                 ↓
hash_prev[pos1] → previous position with same hash
                 ↓
hash_prev[pos2] → previous position
                 ↓
                -1 (end of chain)
```

### Match Search Process

1. Compute hash at current position
2. Follow hash chain backwards
3. For each chain entry:
   - Check if within window (distance ≤ 32768)
   - Try to extend match
   - Keep best match found
4. Stop if:
   - Found "good enough" match
   - Reached max chain length
   - End of chain

### Lazy Matching Strategy

```
Position: 0 1 2 3 4 5 6 7 8 9
Data:     A B C D A B C X Y Z
          ^~~~~~ match len=3 at pos 0
            ^~~~~~~~ match len=4 at pos 1 (better!)
```

Lazy matching defers encoding to check if next position has a better match.

## Performance Characteristics

- **Hash Insertion**: O(1)
- **Match Search**: O(max_chain × max_match_len)
  - Best case: O(1) with good hash
  - Worst case: O(window_size × max_match_len)
- **Memory**: O(window_size) for hash tables
- **Typical**: Fast enough for real-time compression

## Testing

Run tests with:
```bash
moon test lz77
```

Tests cover:
- Hash function distribution
- Match finding
- Back-reference encoding/decoding
- Lazy matching
- Edge cases (short input, no matches)
- Various compression levels

## Dependencies

None - This is a Level 1 package with no external dependencies.

## Used By

- `deflate` (Level 2) - For DEFLATE compression
- Main `zip` package - Via deflate re-exports

## Standards Compliance

Implements LZ77 as required by:
- **RFC 1951** - DEFLATE Compressed Data Format
  - Section 4: Algorithm details
  - Match lengths: 3-258 bytes
  - Distances: 1-32768 bytes
  - 32KB sliding window

## Implementation Notes

- **Hash Function**: 4-byte rolling hash for speed and quality
- **Hash Table Size**: 32768 entries (2^15) balances memory and collisions
- **Window Management**: Circular buffer via modulo arithmetic
- **Match Verification**: Always verifies hash matches with byte comparison
- **Early Exit**: Stops at `good_match` length for speed

## References

- Ziv, Jacob; Lempel, Abraham (1977). "A Universal Algorithm for Sequential Data Compression"
- [RFC 1951 - DEFLATE Specification](https://www.rfc-editor.org/rfc/rfc1951)
- Deutsch, L. Peter (1996). "DEFLATE Compressed Data Format Specification"
