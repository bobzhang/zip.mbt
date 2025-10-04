///|
/// Compression formats supported in ZIP archives
pub(all) enum Compression {
  Stored // No compression
  Deflate // Deflate compression (RFC 1951)
  Bzip2 // Bzip2 (not supported)
  Lzma // LZMA (not supported)
  Xz // XZ (not supported)
  Zstd // Zstandard (not supported)
  Other(Int) // Unknown compression method
} derive(Eq, Show)

///|
/// Convert compression format to ZIP method number
pub fn Compression::to_int(self : Compression) -> Int {
  match self {
    Stored => 0
    Deflate => 8
    Bzip2 => 12
    Lzma => 14
    Zstd => 93
    Xz => 95
    Other(n) => n
  }
}

///|
/// Convert ZIP method number to compression format
#as_free_fn(compression)
pub fn Compression::from_int(compression_method : Int) -> Compression {
  match compression_method {
    0 => Stored
    8 => Deflate
    12 => Bzip2
    14 => Lzma
    93 => Zstd
    95 => Xz
    n => Other(n)
  }
}

///|
/// Convert compression format to human-readable string
pub fn Compression::to_string(self : Compression) -> String {
  match self {
    Stored => "stored"
    Deflate => "deflate"
    Bzip2 => "bzip2"
    Lzma => "lzma"
    Zstd => "zstd"
    Xz => "xz"
    Other(n) => "other(\{n})"
  }
}
