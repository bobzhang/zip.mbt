# DEFLATE Testing Examples

This document provides practical examples of using the Python testing tools.

## Quick Start

### 1. Generate Test Data

```bash
python3 deflate/generate_test_data.py
```

Output:
```
Generating DEFLATE test cases using Python zlib...

✓ Generated test_data.json with 20 test cases
✓ Generated deflate_python_compat_test.mbt

Test Cases Summary:
Name                      Input    Compressed Ratio    Level
======================================================================
empty                     0        2          200.00%  6
single_byte               1        3          300.00%  6
repeated_100              100      6          6.00%    6
hello_world               13       15         115.38%  6
large_text                45000    193        0.43%    6
...
```

### 2. Run Tests

```bash
moon test --target wasm-gc -p deflate
```

Result: **All 63 tests pass** ✓

## Using the Verification Tool

### Example 1: Compress Text

```bash
# "Hello" in hex: 48 65 6c 6c 6f
python3 deflate/verify_deflate.py --compress 48656c6c6f
```

Output:
```
✓ Compressed 5 → 7 bytes
Hex: f348cdc9c90700
```

### Example 2: Decompress Data

```bash
# Decompress the result from above
python3 deflate/verify_deflate.py --decompress f348cdc9c90700
```

Output:
```
✓ Decompression successful (5 bytes)

Decompressed data:
Hello
```

### Example 3: Roundtrip Test

```bash
# Test compress + decompress
python3 deflate/verify_deflate.py --roundtrip 48656c6c6f
```

Output:
```
✓ Roundtrip successful: 5 → 7 bytes (140.0%)
```

### Example 4: Interactive Mode

```bash
python3 deflate/verify_deflate.py --interactive
```

Session:
```
DEFLATE Verification Tool (Python zlib)
==================================================

Commands:
  decompress <hex>     - Decompress DEFLATE data
  compress <hex>       - Compress and show result
  roundtrip <hex>      - Test compress/decompress
  quit                 - Exit

> compress 48656c6c6f
✓ Compressed: 5 → 7 bytes
Hex: f348cdc9c90700

> decompress f348cdc9c90700
✓ Decompression successful (5 bytes)
Data: b'Hello'

> roundtrip 48656c6c6f
✓ Roundtrip successful: 5 → 7 bytes (140.0%)

> quit
```

## Debugging Test Failures

If a test fails, here's how to investigate:

### Step 1: Check test_data.json

```bash
cat deflate/test_data.json | jq '.test_cases[0]'
```

Output:
```json
{
  "name": "empty",
  "input_hex": "",
  "compressed_hex": "0300",
  "input_length": 0,
  "compressed_length": 2,
  "level": 6,
  "compression_ratio": "200.00%"
}
```

### Step 2: Verify with Python

```bash
# Test Python can decompress the data
python3 deflate/verify_deflate.py --decompress 0300
```

### Step 3: Compare with MoonBit

Look at the failing test in `deflate_python_compat_test.mbt` and check:
1. Does MoonBit's `inflate` correctly decompress Python's output?
2. Does MoonBit's `deflate` produce valid output (even if different)?

### Step 4: Check Coverage

```bash
moon coverage analyze -p deflate
```

See which lines aren't covered and add more specific tests.

## Understanding Compression Ratios

Different data types compress differently:

| Data Type | Example | Input | Compressed | Ratio | Explanation |
|-----------|---------|-------|-----------|-------|-------------|
| Empty | `""` | 0 | 2 | 200% | Overhead > data |
| Single byte | `"A"` | 1 | 3 | 300% | Overhead > data |
| Repeated | `"A"*100` | 100 | 6 | 6% | Perfect for LZ77 |
| Random | `range(256)` | 256 | 261 | 102% | No patterns |
| Text | Lorem ipsum | 570 | 62 | 11% | Good patterns |
| Highly repetitive | `"abc"*300` | 900 | 13 | 1.4% | Best case |

**Key insight**: Small data often has negative compression (output > input) due to overhead.

## Test Data Patterns

The generated tests cover:

### 1. Edge Cases
- Empty data (0 bytes)
- Single byte
- Maximum block size (65535 bytes)

### 2. Compression Characteristics
- **Highly compressible**: Repeated patterns (`"A"*1000` → 1.1%)
- **Poorly compressible**: Random binary (`range(256)` → 102%)
- **Typical**: Text data (10-15% of original)

### 3. Compression Levels
- **Level 0**: No compression (stored blocks)
- **Level 1**: Fast (fixed Huffman)
- **Level 6**: Default (dynamic Huffman, moderate effort)
- **Level 9**: Best (dynamic Huffman, maximum effort)

### 4. Real-World Scenarios
- JSON data (1769 bytes → 230 bytes, 13%)
- Large text (45KB → 193 bytes, 0.43%)

## Verifying Against Standards

All tests verify compliance with:
- **RFC 1951**: DEFLATE Compressed Data Format Specification
- **Python zlib**: Industry-standard reference implementation

### Why Python zlib?

1. **Widely used**: Millions of applications rely on it
2. **Well-tested**: Decades of production use
3. **Standard compliant**: Strict RFC 1951 implementation
4. **Easy to access**: Built into Python (no dependencies)

## Extending the Tests

### Add a Custom Test Case

Edit `generate_test_data.py`:

```python
def generate_test_cases():
    test_cases = []
    
    # ... existing cases ...
    
    # Add your custom test
    test_cases.append(create_test_case(
        "my_custom_test",
        b"Your test data here",
        level=6
    ))
    
    return test_cases
```

Then regenerate:

```bash
python3 deflate/generate_test_data.py
moon test --target wasm-gc -p deflate
```

### Test Specific Compression Level

```python
# Test all levels for specific data
sample = b"Test data"
for level in [0, 1, 6, 9]:
    test_cases.append(create_test_case(
        f"custom_level_{level}",
        sample,
        level=level
    ))
```

## Performance Notes

From the generated tests:

- **Small data (< 100 bytes)**: Fixed Huffman typically used
- **Medium data (100-10K bytes)**: Dynamic Huffman shows benefits
- **Large data (> 10K bytes)**: Maximum compression gains

Example from `large_text` test:
- Input: 45,000 bytes
- Compressed: 193 bytes
- Ratio: 0.43% (233x compression!)
- Why: High repetition in text data

## Troubleshooting

### "Decompression failed"
- Check the compressed data is valid DEFLATE (not zlib or gzip)
- Verify it's raw DEFLATE (no headers/trailers)
- Use `--decompress` to test with Python

### "Different compressed output"
- This is **normal and expected**
- Different encoders make different valid choices
- Both should decompress to same input
- Exact match is rare

### "Coverage not improving"
- Some lines are error paths (abort())
- Some are rare compression scenarios
- Focus on reachable code paths
- See `DEFLATE_COMPLETE.md` for uncoverable lines

## Further Reading

- [RFC 1951](https://tools.ietf.org/html/rfc1951) - DEFLATE specification
- [Python zlib docs](https://docs.python.org/3/library/zlib.html)
- [DEFLATE on Wikipedia](https://en.wikipedia.org/wiki/Deflate)
- Project docs: `README_TESTING.md`, `DEFLATE_COMPLETE.md`
