// Deterministic pseudo-random CRC-32 test vectors (Python-aligned)
// Generated via LCG (seed 0x12345678) using gen_crc32_fuzz_expected.js
// Verifies both direct and incremental (chunked) slice-by-8 correctness across varied lengths.

///|
test "crc32_deterministic_fuzz_lengths_python_verified" {
  let lengths : Array[Int] = [
    0, 1, 2, 3, 4, 5, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129,
    255, 256, 257, 511, 512, 513, 1024, 1536, 2048, 3072, 4096,
  ]
  let expect : Array[UInt] = [
    0, 4067256894, 1955164091, 2456118568, 1277456679, 1300956525, 1743212712, 967032586,
    1770471530, 3430343225, 3407643350, 3666845971, 488920029, 1416474953, 487460377,
    421676364, 2655677568, 3153005530, 2964249319, 314206715, 3158496724, 139147605,
    2860146634, 287606996, 3580364271, 2845794043, 2778083554, 4027008611, 2863164746,
    1224901973, 19446512, 100741760,
  ]

  // Global evolving state across each vector (matches generator script behavior)
  let mut state : UInt = 0x12345678
  let next_state = fn(s : UInt) -> UInt {
    (s * 1664525 + 1013904223) & 0xFFFFFFFF
  }
  let mut all_ok = true
  for idx = 0; idx < lengths.length(); idx = idx + 1 {
    let n = lengths[idx]
    let arr : Array[Byte] = []
    for i = 0; i < n; i = i + 1 {
      state = next_state(state)
      let b = (state >> 24) & 0xFF
      arr.push(b.reinterpret_as_int().to_byte())
    }
    let bytes = Bytes::from_array(arr)
    let crc_direct = @crc32.bytes_crc32(bytes[:])
    if crc_direct != expect[idx] {
      all_ok = false
    }
  }
  @json.inspect(all_ok, content=true)
}

///|
test "crc32_deterministic_fuzz_incremental_python_verified" {
  // Same vectors, but feed the data in varied chunk sizes to stress incremental path.
  let lengths : Array[Int] = [
    0, 1, 2, 3, 4, 5, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129,
    255, 256, 257,
  ]
  let expect : Array[UInt] = [
    0, 4067256894, 1955164091, 2456118568, 1277456679, 1300956525, 1743212712, 967032586,
    1770471530, 3430343225, 3407643350, 3666845971, 488920029, 1416474953, 487460377,
    421676364, 2655677568, 3153005530, 2964249319, 314206715, 3158496724, 139147605,
    2860146634, 287606996,
  ]
  let mut state : UInt = 0x12345678
  let next_state = fn(s : UInt) -> UInt {
    (s * 1664525 + 1013904223) & 0xFFFFFFFF
  }
  let mut all_ok = true
  for idx = 0; idx < lengths.length(); idx = idx + 1 {
    let n = lengths[idx]
    // Build sequence with cumulative state (continuing from previous vector)
    let arr : Array[Byte] = []
    for i = 0; i < n; i = i + 1 {
      state = next_state(state)
      let b = (state >> 24) & 0xFF
      arr.push(b.reinterpret_as_int().to_byte())
    }
    let bytes_full = Bytes::from_array(arr)
    // Incremental feed with varying chunk sizes
    let sizes : Array[Int] = [1, 2, 3, 5, 8, 13]
    let mut pos = 0
    let mut crc_state = @crc32.Crc32::init()
    let mut si = 0
    while pos < n {
      let remain = n - pos
      let take = if sizes[si] < remain { sizes[si] } else { remain }
      crc_state = crc_state.update_bytes(bytes_full[pos:pos + take])
      pos = pos + take
      si = (si + 1) % sizes.length()
    }
    let crc_inc = crc_state.finish()
    if crc_inc != expect[idx] {
      all_ok = false
    }
  }
  @json.inspect(all_ok, content=true)
}
