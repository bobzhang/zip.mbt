# RFC 1951 Test Vectors and Examples

## Summary: Does RFC 1951 Provide Test Vectors?

**Answer: NO, RFC 1951 does NOT provide explicit test vectors or test cases.**

The RFC provides:
- ✅ Complete specification of the DEFLATE format
- ✅ Detailed algorithm descriptions
- ✅ Code length and distance tables
- ✅ Example Huffman code construction
- ❌ **NO compressed data examples**
- ❌ **NO test vectors with expected output**
- ❌ **NO sample input/output pairs**

## What RFC 1951 DOES Provide

### 1. **Huffman Code Construction Example** (Section 3.2.2)

The RFC shows how to build Huffman codes from bit lengths:

```
Alphabet: ABCDEFGH
Bit lengths: (3, 3, 3, 3, 3, 2, 4, 4)

Step 1 - Count codes per length:
  N      bl_count[N]
  2      1
  3      5
  4      2

Step 2 - Compute next_code:
  N      next_code[N]
  1      0
  2      0
  3      2
  4      14

Step 3 - Assign codes:
  Symbol  Length  Code
  A       3       010
  B       3       011
  C       3       100
  D       3       101
  E       3       110
  F       2       00
  G       4       1110
  H       4       1111
```

**This is a CONSTRUCTION example, not a compression test case.**

### 2. **Fixed Huffman Codes** (Section 3.2.6)

RFC 1951 defines the fixed Huffman code lengths:
- Literals 0-143: 8 bits (codes 00110000-10111111)
- Literals 144-255: 9 bits (codes 110010000-111111111)
- Lengths 256-279: 7 bits (codes 0000000-0010111)
- Lengths 280-287: 8 bits (codes 11000000-11000111)
- Distances 0-31: 5 bits

**This defines the codes, but provides no test data.**

### 3. **Length/Distance Tables** (Section 3.2.5)

The RFC provides complete tables for:
- Length codes 257-285 with extra bits
- Distance codes 0-29 with extra bits

Example:
```
Length Codes:
  Code  Extra Bits  Length(s)
  257   0           3
  258   0           4
  259   0           5
  ...
  285   0           258

Distance Codes:
  Code  Extra Bits  Distance
  0     0           1
  1     0           2
  2     0           3
  ...
  29    13          24577-32768
```

**These are specification tables, not test cases.**

## What RFC 1951 DOES NOT Provide

### ❌ No Test Vectors
The RFC contains:
- **Zero compressed data examples**
- **Zero input/output pairs**
- **Zero expected results for test inputs**

### ❌ No Reference Implementation Section
The RFC mentions:
> "Source code for a C language implementation of a "deflate" compliant
> compressor and decompressor is available within the zlib package at
> ftp://ftp.uu.net/pub/archiving/zip/zlib/."

But the RFC itself contains **no code or test data**.

### ❌ No Validation Examples
Unlike some RFCs (e.g., RFC 1321 for MD5 which includes test vectors),
RFC 1951 provides only the **specification**, not validation data.

## Why No Test Vectors?

The RFC explicitly states:
> "The material in section 4 [Compression algorithm details] is not part
> of the definition of the specification per se, and a compressor need not
> follow it in order to be compliant."

This means:
- **DEFLATE is a format specification**, not an algorithm specification
- Multiple compression algorithms can produce valid DEFLATE data
- No single "correct" compressed output for a given input
- Test vectors would tie implementations to specific algorithms

## Where to Find Test Data

Since RFC 1951 provides no test vectors, you must use:

### 1. **Reference Implementations**
- **zlib**: The de facto reference (https://zlib.net/)
- **Go's compress/flate**: Clean, well-tested implementation
- **Python's zlib module**: Wraps C zlib

### 2. **Known-Good Files**
- Real ZIP files (e.g., from info-zip)
- PNG files (use DEFLATE for IDAT chunks)
- gzip files (DEFLATE with gzip wrapper)

### 3. **Generate Your Own**
- Use zlib to compress known inputs
- Save as reference test data
- **This is what we did for deflate/test_data.json**

### 4. **Community Test Suites**
- Mark Adler's test suite (zlib developer)
- PNG test suite (uses DEFLATE)
- Go's compress/flate test cases

## Implications for Our Testing

### ✅ **What We're Doing Right**

1. **Using zlib as reference** (deflate/generate_test_data.py)
   - This is the standard approach
   - zlib is the de facto reference implementation

2. **Comprehensive test cases**
   - Edge cases (empty, single byte, etc.)
   - Various compression levels
   - Real-world patterns

3. **End-to-end validation**
   - Compress with MoonBit → decompress with Python
   - Compress with Python → decompress with MoonBit

### ⚠️ **What We Should Add**

1. **Known-good file tests**
   - Real ZIP files
   - Known DEFLATE streams from other tools

2. **Fuzzing**
   - Random data generation
   - Ensure no crashes on invalid input

3. **Cross-validation**
   - Compare MoonBit output with multiple decompressors
   - zlib, Go, Node.js, etc.

## Conclusion

**RFC 1951 provides:**
- ✅ Complete format specification
- ✅ Algorithm recommendations
- ✅ Huffman code construction rules
- ❌ **NO test vectors or test cases**

**For testing, we must rely on:**
1. Reference implementations (zlib, Go, etc.)
2. Generated test data (what we're doing)
3. Real-world files
4. Property-based testing

**Our current approach is correct and standard practice.**

The lack of RFC test vectors is why:
- Every DEFLATE implementation tests against zlib
- Our Python-based test generation is industry standard
- Cross-validation with multiple decompressors is important

## References

- **RFC 1951**: https://www.rfc-editor.org/rfc/rfc1951.txt
- **zlib**: https://zlib.net/
- **Go compress/flate tests**: https://github.com/golang/go/tree/master/src/compress/flate
- **PNG test suite**: http://www.schaik.com/pngsuite/ (uses DEFLATE)
