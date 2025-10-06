// Tests for LZ77 string matching functions

///|
test "hash4_basic" {
  // Test hash function with known values
  let data = b"test"
  let hash = @lz77.hash4(data, 0)

  // Hash should be in valid range [0, 32767]
  let valid = hash >= 0 && hash < 32768
  @json.inspect(valid, content=true)
}

///|
test "hash4_same_string_same_hash" {
  let data1 = b"hello world"
  let data2 = b"xhello world"

  // Same 4 bytes should produce same hash
  let hash1 = @lz77.hash4(data1, 0) // "hell"
  let hash2 = @lz77.hash4(data2, 1) // "hell"
  @json.inspect(hash1 == hash2, content=true)
}

///|
test "hash4_different_string_likely_different_hash" {
  let data = b"abcdefgh"
  let hash1 = @lz77.hash4(data, 0) // "abcd"
  let hash2 = @lz77.hash4(data, 4) // "efgh"

  // Different strings should (usually) have different hashes
  // Not guaranteed but very likely with good hash function
  @json.inspect(hash1 != hash2, content=true)
}

///|
test "insert_hash_basic" {
  let hash_head = Array::make(32768, -1)
  let hash_prev = Array::make(32768, 0)

  // Insert position 100 at hash 42
  @lz77.insert_hash(hash_head, hash_prev, 42, 100)
  @json.inspect((hash_head[42], hash_prev[100 % 32768]), content=[100, -1])
}

///|
test "insert_hash_chain" {
  let hash_head = Array::make(32768, -1)
  let hash_prev = Array::make(32768, 0)

  // Insert multiple positions with same hash (collision chain)
  @lz77.insert_hash(hash_head, hash_prev, 42, 100)
  @lz77.insert_hash(hash_head, hash_prev, 42, 200)
  @lz77.insert_hash(hash_head, hash_prev, 42, 300)

  // Should create a chain: 300 -> 200 -> 100 -> -1
  @json.inspect(
    (
      hash_head[42],
      hash_prev[300 % 32768],
      hash_prev[200 % 32768],
      hash_prev[100 % 32768],
    ),
    content=[300, 200, 100, -1],
  )
}

///|
test "match_fwd_identical" {
  let data = b"hello world hello"

  // Match from position 0 ("hello") with position 12 ("hello")
  let len = @lz77.match_fwd(data, 0, 12, 0, 10)
  @json.inspect(len, content=5) // "hello" = 5 chars
}

///|
test "match_fwd_partial" {
  let data = b"hello world help"

  // Match from position 0 ("hello") with position 12 ("help")
  let len = @lz77.match_fwd(data, 0, 12, 0, 10)
  @json.inspect(len, content=3) // "hel" = 3 chars
}

///|
test "match_fwd_max_limit" {
  // Create data with long repeated sequence
  let buf = @buffer.ByteBuf::new(100)
  for i = 0; i < 100; i = i + 1 {
    buf.write_byte(b'a')
  }
  let data = buf.contents()

  // Match should stop at max_match_len even if more matches exist
  let len = @lz77.match_fwd(data, 0, 1, 0, 10)
  @json.inspect(len, content=10) // Limited to max_match_len
}

///|
test "find_match_length_basic" {
  let data = b"hello world hello world"

  // Find match between position 0 and 12 (both "hello world")
  let len = @lz77.find_match_length(data, 0, 12, 2, 20)

  // Should find full match "hello world" = 11 characters
  @json.inspect(len, content=11)
}

///|
test "find_match_length_requires_longer" {
  let data = b"abcdef abcxyz"

  // Match from 0 ("abc") with 7 ("abc")
  // prev_match_len = 3, but match is only 3 chars
  // Should return 0 because we need STRICTLY longer than prev_match_len
  let len = @lz77.find_match_length(data, 0, 7, 3, 10)
  @json.inspect(len, content=0)
}

///|
test "backref_packing" {
  // Test backref encoding/decoding
  let bref = @lz77.make_backref(100, 5)
  @json.inspect((@lz77.backref_dist(bref), @lz77.backref_len(bref)), content=[
    100, 5,
  ])
}

///|
test "backref_large_values" {
  // Test with larger distance and length
  let bref = @lz77.make_backref(32768, 258)
  @json.inspect((@lz77.backref_dist(bref), @lz77.backref_len(bref)), content=[
    32768, 258,
  ])
}

///|
test "find_backref_basic" {
  // Create data with repeated pattern: "hello world hello"
  let data = b"hello world hello"

  // Initialize hash tables
  let hash_head = Array::make(32768, -1)
  let hash_prev = Array::make(32768, 0)

  // Insert position 0 ("hell")
  let hash0 = @lz77.hash4(data, 0)
  @lz77.insert_hash(hash_head, hash_prev, hash0, 0)

  // Now search for match at position 12 ("hell")
  let hash12 = @lz77.hash4(data, 12)
  let bref = @lz77.find_backref(
    data, hash_head, hash_prev, 12, // Current position
     hash12, 0, // No previous match
     10, // Max match length
     4, // Good match threshold
     4096, // Max chain length
  )

  // Should find match: distance=12, length=5 ("hello")
  @json.inspect((@lz77.backref_dist(bref), @lz77.backref_len(bref)), content=[
    12, 5,
  ])
}

///|
test "find_backref_no_match" {
  let data = b"abcdefghij"
  let hash_head = Array::make(32768, -1)
  let hash_prev = Array::make(32768, 0)

  // Insert position 0
  let hash0 = @lz77.hash4(data, 0)
  @lz77.insert_hash(hash_head, hash_prev, hash0, 0)

  // Search at position 6 with different hash - should find no match
  let hash6 = @lz77.hash4(data, 6)
  let bref = @lz77.find_backref(
    data, hash_head, hash_prev, 6, hash6, 0, 10, 4, 4096,
  )
  @json.inspect(bref, content=0) // No match
}

///|
test "find_backref_requires_min_length" {
  // Create data where only 2 bytes match (less than min of 3)
  let data = b"abXXXXabYYYY"
  let hash_head = Array::make(32768, -1)
  let hash_prev = Array::make(32768, 0)

  // Insert position 0 ("abXX")
  let hash0 = @lz77.hash4(data, 0)
  @lz77.insert_hash(hash_head, hash_prev, hash0, 0)

  // Search at position 6 ("abYY") - first 2 bytes match but not enough
  let hash6 = @lz77.hash4(data, 6)
  let bref = @lz77.find_backref(
    data, hash_head, hash_prev, 6, hash6, 0, 10, 4, 4096,
  )

  // Should find no match because only 2 bytes match (< min 3)
  @json.inspect(bref, content=0)
}
