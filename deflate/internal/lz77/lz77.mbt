///|
/// LZ77 string matching for DEFLATE compression
/// 
/// Implements the LZ77 sliding window compression algorithm:
/// - Hash chain for finding repeated strings
/// - Bidirectional matching for speed
/// - Back-reference encoding (distance, length pairs)

// LZ77 constants
pub let min_match_len : Int32 = 3 // Minimum match length

///|
pub let max_match_len : Int32 = 258 // Maximum match length (same as length_max)

///|
let max_match_dist : Int32 = 32768 // Maximum back-reference distance

///|
pub let window_size : Int32 = 32768 // Sliding window size

///|
let hash_bit_size : Int32 = 15 // Hash table size = 2^15 = 32768

///|
pub let hash_size : Int32 = 32768 // 1 << hash_bit_size

///|
pub let no_pos : Int32 = -1 // Marker for no position

///|
/// Compute rolling hash of 4 bytes starting at position i
/// Uses Fibonacci hashing: multiply by golden ratio and take upper bits
pub fn hash4(bytes : BytesView) -> Int32 {
  guard! bytes is [u32le(v), ..]
  // Fibonacci hash: multiply by golden ratio approximation
  let hmul : UInt32 = 0x9E3779B1 // 2^32 / phi, where phi = golden ratio
  let product = v * hmul
  ((product >> (32 - hash_bit_size)) & 0x7FFF).reinterpret_as_int() // Extract high 15 bits of 32-bit hash
}

///|
/// Insert position into hash chain
pub fn insert_hash(
  hash_head : Array[Int32],
  hash_prev : Array[Int32],
  hash : Int32,
  pos : Int32,
) -> Unit {
  hash_prev[pos % window_size] = hash_head[hash]
  hash_head[hash] = pos
}

///|
/// Match bytes backward from positions i and j for len bytes
/// Returns -1 if all match, or the count of remaining unmatched bytes
fn match_bwd(bytes : BytesView, i : Int32, j : Int32, len : Int32) -> Int32 {
  if len < 0 {
    return len
  }
  if bytes[i].to_int() == bytes[j].to_int() {
    match_bwd(bytes, i - 1, j - 1, len - 1)
  } else {
    len
  }
}

///|
/// Match bytes forward from positions i and j, up to max_match_len
/// Returns the length of the match
pub fn match_fwd(
  bytes : BytesView,
  i : Int32,
  j : Int32,
  len : Int32,
  max_match_len : Int32,
) -> Int32 {
  if len >= max_match_len {
    return len
  }
  if i >= bytes.length() || j >= bytes.length() {
    return len
  }
  if bytes[i].to_int() == bytes[j].to_int() {
    match_fwd(bytes, i + 1, j + 1, len + 1, max_match_len)
  } else {
    len
  }
}

///|
/// Find match length between positions i and j
/// Only returns a length if it's strictly longer than prev_match_len
/// Uses bidirectional matching: check backward first, then forward
pub fn find_match_length(
  bytes : BytesView,
  i : Int32,
  j : Int32,
  prev_match_len : Int32,
  max_match_len : Int32,
) -> Int32 {
  let newi = i + prev_match_len
  let newj = j + prev_match_len
  if newi >= bytes.length() || newj >= bytes.length() {
    return 0
  }

  // Check backward from prev_match_len position
  if match_bwd(bytes, newi, newj, prev_match_len) < 0 {
    // Backward match succeeded, try forward
    match_fwd(bytes, newi + 1, newj + 1, prev_match_len + 1, max_match_len)
  } else {
    0 // Backward match failed
  }
}

///|
/// Back-reference: represents a (distance, length) pair for LZ77
/// Packed into a single Int: (distance << 16) | length
/// If distance == 0, it's a literal (length is the byte value)
pub fn make_backref(dist : Int32, len : Int32) -> Int32 {
  (dist << 16) | len
}

///|
pub fn backref_dist(bref : Int32) -> Int32 {
  // Extract upper 16 bits, handling the bit pattern correctly
  let bits = bref & -65536 // Mask to keep only upper 16 bits
  if bits < 0 {
    // Negative means bit 31 was set, need to handle as unsigned
    (bits >> 16) & 0xFFFF
  } else {
    bits >> 16
  }
}

///|
pub fn backref_len(bref : Int32) -> Int32 {
  bref & 0xFFFF
}

///|
/// Find the best back-reference match starting at position pos
/// Returns a backref (0 if no good match found)
/// Uses hash chain to search previous positions with same hash
/// Parameters:
/// - good_match: If match >= this length, reduce search effort (quality vs speed)
/// - max_chain_len: Maximum number of hash chain entries to check
pub fn find_backref(
  bytes : BytesView,
  hash_head : Array[Int32],
  hash_prev : Array[Int32],
  pos : Int32,
  hash : Int32,
  prev_match_len : Int32,
  max_match_len : Int32,
  good_match : Int32,
  max_chain_len : Int32,
) -> Int32 {
  // Adjust prev_match_len: we want at least min_match_len
  let prev_len = if prev_match_len == 0 {
    min_match_len - 1
  } else {
    prev_match_len
  }

  // Early exit if already at max
  if prev_len >= max_match_len {
    return 0
  }

  // Adjust chain length based on match quality
  let chain_steps = if prev_len >= good_match {
    max_chain_len / 4 // Reduce effort if we already have a good match
  } else {
    max_chain_len
  }

  // Search the hash chain for best match
  fn search_chain(
    chain_left : Int32,
    i : Int32,
    match_pos : Int32,
    best_len : Int32,
  ) -> Int32 {
    if i == no_pos || chain_left == 0 || pos - i > max_match_dist {
      // End of chain or out of range
      if match_pos == no_pos {
        0 // No match found
      } else {
        make_backref(pos - match_pos, best_len)
      }
    } else {
      // Try to find match at position i
      let len = find_match_length(bytes, i, pos, best_len, max_match_len)
      if len == max_match_len {
        // Found maximum possible match, stop searching
        make_backref(pos - i, len)
      } else if len > 0 {
        // Found a better match, continue searching
        let next_i = hash_prev[i.mod(window_size)]
        search_chain(chain_left - 1, next_i, i, len)
      } else {
        // No better match, continue searching
        let next_i = hash_prev[i.mod(window_size)]
        search_chain(chain_left - 1, next_i, match_pos, best_len)
      }
    }
  }

  let start_i = hash_head[hash]
  search_chain(chain_steps, start_i, no_pos, prev_len)
}
