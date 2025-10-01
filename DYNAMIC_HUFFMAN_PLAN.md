# Dynamic Huffman Implementation Plan

## Status: Ready to Implement

This document describes the plan to add Dynamic Huffman encoding to the MoonBit ZIP library, which will provide 10-20% better compression ratios compared to Fixed Huffman.

## Current State

✅ **COMPLETED:**
- zlib wrapper format (RFC 1950) - 100% complete
- LZ77 string matching - 100% complete  
- Fixed Huffman encoding - 100% complete
- All inflate (decompression) features - 100% complete

⚠️ **TODO:**
- Dynamic Huffman encoding (~400 lines)
- Block type selection heuristic (~100 lines)
- Multi-block support (~150 lines)

## Dynamic Huffman Overview

Dynamic Huffman (BTYPE=2) allows custom Huffman trees to be sent with each compressed block, optimized for that block's symbol distribution. This typically improves compression by 10-20% over Fixed Huffman.

### Components Required

1. **Frequency Counting** (DURING LZ77 matching)
   - Count literal/length symbol frequencies
   - Count distance symbol frequencies
   - Maintain two frequency arrays

2. **Optimal Code Length Computation** (~150 lines)
   - Package-Merge algorithm for bounded code lengths
   - Must respect 15-bit maximum code length
   - Handle trivial cases (0, 1, or 2 symbols)

3. **Canonical Huffman Code Generation** (~50 lines)
   - Convert code lengths to actual codes
   - Use canonical Huffman construction
   - Bit-reverse codes for LSB-first output

4. **Code Length Encoding** (~100 lines)
   - Encode the Huffman code lengths themselves
   - Use run-length encoding (symbols 16, 17, 18)
   - Build codelen Huffman tree (max 7 bits)

5. **Dynamic Block Header Writing** (~50 lines)
   - Write HLIT (litlen codes - 257)
   - Write HDIST (dist codes - 1)
   - Write HCLEN (codelen codes - 4)
   - Write codelen code lengths in specific order
   - Write encoded litlen and dist code lengths

6. **Block Symbol Writing** (SHARED with fixed Huffman)
   - Reuse existing write_block_symbols logic
   - Works with any Huffman encoder

## Implementation Steps

### Step 1: Add Frequency Counting (~30 lines)

Modify LZ77 compression loop to maintain frequency counts:

```moonbit
struct FrequencyCounter {
  litlen_freqs : Array[Int]  // 286 symbols
  dist_freqs : Array[Int]    // 30 symbols
}

fn FrequencyCounter::new() -> FrequencyCounter {
  {
    litlen_freqs: Array::make(286, 0),
    dist_freqs: Array::make(30, 0)
  }
}

fn FrequencyCounter::add_literal(self, lit : Int) -> Unit {
  self.litlen_freqs[lit] = self.litlen_freqs[lit] + 1
}

fn FrequencyCounter::add_length(self, len : Int) -> Unit {
  let sym = length_value_to_sym[len]
  self.litlen_freqs[sym] = self.litlen_freqs[sym] + 1
}

fn FrequencyCounter::add_distance(self, dist : Int) -> Unit {
  let sym = dist_value_to_sym(dist)
  self.dist_freqs[sym] = self.dist_freqs[sym] + 1
}

fn FrequencyCounter::add_end_of_block(self) -> Unit {
  self.litlen_freqs[256] = 1  // Always exactly one EOB
}
```

### Step 2: Optimal Code Length Computation (~150 lines)

Implement Package-Merge algorithm:

```moonbit
fn build_optimal_code_lengths(
  freqs : Array[Int],
  max_sym : Int,
  max_code_len : Int
) -> Array[Int] {
  // Package-Merge algorithm
  // 1. Create initial packages (leaf nodes)
  // 2. Merge packages max_code_len times
  // 3. Count packages to determine code lengths
  
  // Simplified version for first implementation:
  // Use greedy tree building with length limiting
  ...
}
```

### Step 3: Canonical Huffman Code Generation (~50 lines)

```moonbit
fn build_canonical_codes(
  lengths : Array[Int],
  max_sym : Int
) -> HuffmanEncoder {
  let encoder = HuffmanEncoder::new()
  
  // Count codes of each length
  let count = Array::make(16, 0)
  for i = 0; i <= max_sym; i = i + 1 {
    count[lengths[i]] = count[lengths[i]] + 1
  }
  
  // Compute first code of each length
  let next_code = Array::make(16, 0)
  let code = 0
  for len = 1; len <= 15; len = len + 1 {
    code = (code + count[len - 1]) << 1
    next_code[len] = code
  }
  
  // Assign codes to symbols
  for sym = 0; sym <= max_sym; sym = sym + 1 {
    let len = lengths[sym]
    if len > 0 {
      let c = next_code[len]
      let bits = reverse_bits(c, len)
      encoder.set(sym, sym_info_make(bits, len))
      next_code[len] = c + 1
    }
  }
  
  encoder
}
```

### Step 4: Code Length Encoding (~100 lines)

```moonbit
// Code length symbols:
// 0-15: Literal code length
// 16: Repeat previous length 3-6 times (2 extra bits)
// 17: Repeat zero 3-10 times (3 extra bits)
// 18: Repeat zero 11-138 times (7 extra bits)

fn encode_code_lengths(
  litlen_lengths : Array[Int],
  dist_lengths : Array[Int],
  hlit : Int,  // litlen symbols - 257
  hdist : Int  // dist symbols - 1
) -> (Array[Int], Array[Int], Int) {
  // Returns (codelen_syms, codelen_freqs, codelen_count)
  
  // Concatenate litlen and dist lengths
  let total_len = (hlit + 257) + (hdist + 1)
  let all_lengths = Array::make(total_len, 0)
  ...
  
  // Run-length encode
  let codelen_syms = Array::make(total_len, 0)
  let codelen_freqs = Array::make(19, 0)  // 19 codelen symbols
  let mut sym_count = 0
  
  let mut i = 0
  while i < total_len {
    let len = all_lengths[i]
    
    if len == 0 {
      // Count zeros
      let mut zero_count = 1
      while i + zero_count < total_len && all_lengths[i + zero_count] == 0 {
        zero_count = zero_count + 1
      }
      
      if zero_count < 3 {
        // Output as literal
        codelen_syms[sym_count] = 0
        codelen_freqs[0] = codelen_freqs[0] + 1
        sym_count = sym_count + 1
        i = i + 1
      } else if zero_count <= 10 {
        // Use symbol 17
        codelen_syms[sym_count] = 17 | ((zero_count - 3) << 8)
        codelen_freqs[17] = codelen_freqs[17] + 1
        sym_count = sym_count + 1
        i = i + zero_count
      } else {
        // Use symbol 18
        let count = zero_count.min(138)
        codelen_syms[sym_count] = 18 | ((count - 11) << 8)
        codelen_freqs[18] = codelen_freqs[18] + 1
        sym_count = sym_count + 1
        i = i + count
      }
    } else {
      // Non-zero length
      codelen_syms[sym_count] = len
      codelen_freqs[len] = codelen_freqs[len] + 1
      sym_count = sym_count + 1
      
      // Check for repeats
      let mut repeat_count = 1
      while i + repeat_count < total_len && 
            all_lengths[i + repeat_count] == len &&
            repeat_count < 6 {
        repeat_count = repeat_count + 1
      }
      
      if repeat_count >= 3 {
        // Use symbol 16
        codelen_syms[sym_count] = 16 | ((repeat_count - 3) << 8)
        codelen_freqs[16] = codelen_freqs[16] + 1
        sym_count = sym_count + 1
      }
      
      i = i + repeat_count
    }
  }
  
  (codelen_syms, codelen_freqs, sym_count)
}
```

### Step 5: Dynamic Block Header Writing (~50 lines)

```moonbit
fn write_dynamic_header(
  writer : BitWriter,
  litlen_encoder : HuffmanEncoder,
  dist_encoder : HuffmanEncoder,
  codelen_encoder : HuffmanEncoder,
  codelen_syms : Array[Int],
  sym_count : Int
) -> Unit {
  // Compute HLIT, HDIST, HCLEN
  let hlit = litlen_encoder.max_sym - 257
  let hdist = dist_encoder.max_sym - 1
  
  // Find last non-zero codelen code length
  let codelen_order = [|16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15|]
  let mut hclen = 18
  while hclen > 0 {
    let sym = codelen_order[hclen]
    if sym_info_code_length(codelen_encoder.get(sym)) > 0 {
      break
    }
    hclen = hclen - 1
  }
  
  // Write HLIT (5 bits)
  writer.write_bits(hlit, 5)
  
  // Write HDIST (5 bits)
  writer.write_bits(hdist, 5)
  
  // Write HCLEN (4 bits)
  writer.write_bits(hclen, 4)
  
  // Write codelen code lengths (3 bits each)
  for i = 0; i <= hclen; i = i + 1 {
    let sym = codelen_order[i]
    let len = sym_info_code_length(codelen_encoder.get(sym))
    writer.write_bits(len, 3)
  }
  
  // Write encoded litlen and dist code lengths
  for i = 0; i < sym_count; i = i + 1 {
    let sym_info = codelen_syms[i]
    let sym = sym_info & 0xFF
    let extra_bits = sym_info >> 8
    
    let info = codelen_encoder.get(sym)
    let code = sym_info_code(info)
    let code_len = sym_info_code_length(info)
    
    writer.write_bits(code, code_len)
    
    // Write extra bits for symbols 16, 17, 18
    match sym {
      16 => writer.write_bits(extra_bits, 2)
      17 => writer.write_bits(extra_bits, 3)
      18 => writer.write_bits(extra_bits, 7)
      _ => ()
    }
  }
}
```

### Step 6: Main deflate_dynamic Function (~50 lines)

```moonbit
pub fn deflate_dynamic(
  bytes : Bytes,
  start : Int,
  len : Int,
  is_final : Bool,
  good_match : Int,
  max_chain : Int
) -> Bytes {
  // 1. Run LZ77 with frequency counting
  let freqs = FrequencyCounter::new()
  let symbols = compress_with_frequency_counting(bytes, start, len, freqs, good_match, max_chain)
  
  // 2. Build optimal Huffman trees
  let litlen_lengths = build_optimal_code_lengths(freqs.litlen_freqs, 285, 15)
  let litlen_encoder = build_canonical_codes(litlen_lengths, 285)
  
  let dist_lengths = build_optimal_code_lengths(freqs.dist_freqs, 29, 15)
  let dist_encoder = build_canonical_codes(dist_lengths, 29)
  
  // 3. Encode code lengths
  let (codelen_syms, codelen_freqs, sym_count) = 
    encode_code_lengths(litlen_lengths, dist_lengths, hlit, hdist)
  
  // 4. Build codelen Huffman tree
  let codelen_lengths = build_optimal_code_lengths(codelen_freqs, 18, 7)
  let codelen_encoder = build_canonical_codes(codelen_lengths, 18)
  
  // 5. Write dynamic block
  let output = ByteBuf::new(len * 2, false)
  let writer = BitWriter::new(output)
  
  let header = if is_final { 0b101 } else { 0b100 }
  writer.write_bits(header, 3)
  
  write_dynamic_header(writer, litlen_encoder, dist_encoder, codelen_encoder, codelen_syms, sym_count)
  write_block_symbols(writer, symbols, litlen_encoder, dist_encoder)
  
  writer.flush()
  output.contents()
}
```

## Testing Strategy

### Test 1: Simple Dynamic Huffman
```moonbit
test "dynamic_huffman_simple" {
  let data = "AAAAAABBBBBBCCCCCC"  // Clearly non-uniform distribution
  let compressed = deflate_dynamic(data.to_bytes(), 0, data.length(), true, 8, 128)
  
  // Should be smaller than fixed Huffman
  let fixed = deflate_fixed(data.to_bytes(), 0, data.length(), true, 8, 128)
  assert_true!(compressed.length() < fixed.length())
  
  // Should decompress correctly
  match inflate(compressed, 0, compressed.length()) {
    Ok(decompressed) => {
      assert_eq!(decompressed.to_string(), data)
    }
    Err(e) => fail!("Decompression failed: \{e}")
  }
}
```

### Test 2: All Same Symbol
```moonbit
test "dynamic_huffman_single_symbol" {
  let data = "AAAAAAAAAA"
  let compressed = deflate_dynamic(data.to_bytes(), 0, data.length(), true, 8, 128)
  
  // Single symbol should compress very well
  assert_true!(compressed.length() < data.length() / 2)
  
  match inflate(compressed, 0, compressed.length()) {
    Ok(decompressed) => {
      assert_eq!(decompressed.to_string(), data)
    }
    Err(e) => fail!("Decompression failed: \{e}")
  }
}
```

### Test 3: Comparison with Fixed Huffman
```moonbit
test "dynamic_vs_fixed_compression" {
  let test_cases = [
    "Hello, World!",
    "AAAAABBBBBCCCCCDDDDD",
    "The quick brown fox jumps over the lazy dog",
    "aaaaaaaaaaaabbbbbbbbbbbbcccccccccccc",
  ]
  
  for test_data in test_cases {
    let dynamic = deflate_dynamic(test_data.to_bytes(), 0, test_data.length(), true, 8, 128)
    let fixed = deflate_fixed(test_data.to_bytes(), 0, test_data.length(), true, 8, 128)
    
    // Dynamic should be smaller or equal
    assert_true!(dynamic.length() <= fixed.length())
    
    // Both should decompress correctly
    match inflate(dynamic, 0, dynamic.length()) {
      Ok(d) => assert_eq!(d.to_string(), test_data)
      Err(e) => fail!("Dynamic decompression failed: \{e}")
    }
    
    match inflate(fixed, 0, fixed.length()) {
      Ok(d) => assert_eq!(d.to_string(), test_data)
      Err(e) => fail!("Fixed decompression failed: \{e}")
    }
  }
}
```

### Test 4: Empty Data
```moonbit
test "dynamic_huffman_empty" {
  let compressed = deflate_dynamic(Bytes::new(0), 0, 0, true, 8, 128)
  
  match inflate(compressed, 0, compressed.length()) {
    Ok(decompressed) => {
      assert_eq!(decompressed.length(), 0)
    }
    Err(e) => fail!("Decompression failed: \{e}")
  }
}
```

### Test 5: Long Repetitive Data
```moonbit
test "dynamic_huffman_repetitive" {
  let data = "A".repeat(1000)
  let compressed = deflate_dynamic(data.to_bytes(), 0, data.length(), true, 8, 128)
  
  // Should compress very well (< 5% of original)
  assert_true!(compressed.length() < data.length() / 20)
  
  match inflate(compressed, 0, compressed.length()) {
    Ok(decompressed) => {
      assert_eq!(decompressed.to_string(), data)
    }
    Err(e) => fail!("Decompression failed: \{e}")
  }
}
```

## Expected Outcomes

- **Compression Ratio**: 10-20% better than Fixed Huffman on typical data
- **Code Size**: ~400 lines of new code
- **Test Count**: +10-15 tests
- **Performance**: Slightly slower than Fixed Huffman (acceptable tradeoff)
- **Compatibility**: 100% - dynamic blocks already decompress correctly

## Integration Plan

1. Implement and test each component individually
2. Integrate into main compression flow
3. Add block type selection heuristic to choose between stored/fixed/dynamic
4. Update File::deflate_of_bytes() to use dynamic Huffman by default
5. Run comprehensive test suite
6. Document new functionality

## Next Steps After Dynamic Huffman

1. **Block Type Selection** (~100 lines, ~8 tests)
   - Estimate size for each block type
   - Choose optimal type

2. **Multi-Block Support** (~150 lines, ~5 tests)
   - Handle data > 65KB efficiently
   - Proper BFINAL flag handling

3. **Performance Optimization**
   - Profile compression speed
   - Optimize hot paths

## References

- RFC 1951: DEFLATE Compressed Data Format Specification
- Package-Merge Algorithm: "A Fast Algorithm for Optimal Length-Limited Huffman Codes"
- OCaml zipc implementation (reference)
