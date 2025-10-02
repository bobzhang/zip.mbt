# types - Common Types and Utilities

**Level**: 2  
**Package**: `bobzhang/zip/types`  
**Dependencies**: `types/fpath`

## Overview

The `types` package provides common type definitions and utilities used throughout the ZIP library, including compression types, file paths, and POSIX time handling.

## Sub-Packages

- **`types/fpath`**: File path manipulation and validation

## Features

- **Compression Enum**: Type-safe compression method representation
- **POSIX Time**: Unix timestamp handling with DOS time conversion
- **File Paths**: Unix-style path utilities (via fpath sub-package)

## API

### Compression

#### `pub enum Compression`

```moonbit
pub enum Compression {
  Stored    // No compression (method 0)
  Deflate   // DEFLATE compression (method 8)
  // Future: Bzip2, LZMA, etc.
} derive(Eq, Show)
```

Represents ZIP compression methods.

#### Functions

```moonbit
pub fn Compression::from_int(method : Int) -> Compression
pub fn Compression::to_int(self : Compression) -> Int
```

Convert between compression enum and ZIP method codes.

**Method Codes:**
- `0` = Stored (no compression)
- `8` = DEFLATE

### POSIX Time (Ptime)

#### `pub typealias Int64 as Ptime`

POSIX timestamp (seconds since 1970-01-01 00:00:00 UTC).

#### Constants

```moonbit
pub let dos_epoch : Ptime  // 1980-01-01 00:00:00 UTC
```

DOS epoch (ZIP file format epoch).

#### Functions

##### `ptime_to_date_time(ptime : Ptime) -> ((Int, Int, Int), (Int, Int, Int))`

Convert POSIX time to date and time components.

**Returns:** `((year, month, day), (hour, minute, second))`

##### `ptime_of_dos_date_time(dos_date : Int, dos_time : Int) -> Ptime`

Convert DOS date/time to POSIX timestamp.

**DOS Format:**
- Date: `(year-1980) << 9 | month << 5 | day`
- Time: `hour << 11 | minute << 5 | (second / 2)`

##### `ptime_to_dos_date_time(ptime : Ptime) -> (Int, Int)`

Convert POSIX timestamp to DOS date/time format.

**Returns:** `(dos_date, dos_time)`

##### `ptime_format(ptime : Ptime) -> String`

Format POSIX time as ISO 8601-like string.

**Format:** `"YYYY-MM-DD HH:MM:SS"`

### File Paths (Fpath)

#### `pub typealias String as Fpath`

File path type (re-exported from `types/fpath`).

#### Functions

```moonbit
pub fn fpath_ensure_unix(path : Fpath) -> Fpath
```

Convert Windows-style paths (`\`) to Unix-style (`/`).

```moonbit
pub fn fpath_ensure_directoryness(path : Fpath) -> Fpath
```

Ensure directory paths end with `/`.

```moonbit
pub fn fpath_sanitize(path : Fpath) -> Fpath
```

Remove redundant separators and normalize path.

## Usage Examples

### Compression Types

```moonbit
// Create from ZIP method code
let compression = Compression::from_int(8)  // DEFLATE
match compression {
  Stored => println("No compression")
  Deflate => println("DEFLATE compression")
}

// Convert to method code
let method = compression.to_int()  // 8
```

### Time Conversion

```moonbit
// Get current time as POSIX timestamp
let now : Ptime = current_time()

// Convert to DOS format for ZIP
let (dos_date, dos_time) = ptime_to_dos_date_time(now)

// Store in ZIP file...

// Later, read from ZIP
let mtime = ptime_of_dos_date_time(dos_date, dos_time)
println("Modified: \{ptime_format(mtime)}")
// Output: "Modified: 2025-10-02 14:30:45"
```

### Date/Time Components

```moonbit
let ((year, month, day), (hour, minute, second)) = ptime_to_date_time(now)
println("\{year}-\{month}-\{day} \{hour}:\{minute}:\{second}")
```

### File Paths

```moonbit
// Normalize Windows path
let path = fpath_ensure_unix("dir\\subdir\\file.txt")
// Result: "dir/subdir/file.txt"

// Ensure directory
let dir = fpath_ensure_directoryness("mydir")
// Result: "mydir/"

// Sanitize path
let clean = fpath_sanitize("dir//subdir/./file.txt")
// Result: "dir/subdir/file.txt"
```

## DOS Date/Time Format

### Date Format (16 bits)

```
Bits 15-9: Year (0 = 1980, 127 = 2107)
Bits 8-5:  Month (1-12)
Bits 4-0:  Day (1-31)
```

### Time Format (16 bits)

```
Bits 15-11: Hour (0-23)
Bits 10-5:  Minute (0-59)
Bits 4-0:   Second / 2 (0-29, representing 0-58 seconds)
```

**Note:** DOS time has 2-second resolution.

### Example

```moonbit
// October 2, 2025, 14:30:45
// DOS Date: (2025-1980) << 9 | 10 << 5 | 2 = 0x5A82
// DOS Time: 14 << 11 | 30 << 5 | (45/2) = 0x73D6

let dos_date = 0x5A82
let dos_time = 0x73D6
let ptime = ptime_of_dos_date_time(dos_date, dos_time)
println(ptime_format(ptime))
// Output: "2025-10-02 14:30:44" (45 seconds rounded down to 44)
```

## Time Range Limitations

### DOS Epoch
- **Minimum**: 1980-01-01 00:00:00
- **Maximum**: 2107-12-31 23:59:58

### ZIP File Behavior
- Times before 1980 are clamped to DOS epoch
- Times after 2107 are clamped to max DOS time
- 2-second resolution (odd seconds rounded down)

## Implementation Notes

### Compression
- Extensible enum for future compression methods
- Type-safe method codes
- Easy to add new methods (Bzip2, LZMA, etc.)

### Time Handling
- All internal times are POSIX timestamps (Int64)
- DOS conversion only at ZIP I/O boundaries
- Timezone-agnostic (UTC assumed)
- Leap second handling: not supported (matches DOS/ZIP spec)

### File Paths
- All paths normalized to Unix-style (`/` separator)
- Directory paths always end with `/`
- Relative paths supported
- No validation of path legality (allows any string)

## Testing

Run tests with:
```bash
moon test types
```

Tests cover:
- Compression type conversion
- DOS time conversion (boundary cases)
- Date/time formatting
- Path normalization
- Epoch handling

## Dependencies

- `types/fpath` (Level 1) - File path utilities

## Used By

- Main `zip` package - For file metadata
- All packages needing compression types or time handling

## Future Enhancements

Potential additions:
- More compression methods (Bzip2, LZMA, etc.)
- Extended timestamps (ZIP64)
- Timezone support
- Path validation and security checks
- Unicode normalization for paths

## References

- [ZIP File Format Specification](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT)
- [MS-DOS Date and Time Format](https://docs.microsoft.com/en-us/windows/win32/sysinfo/ms-dos-date-and-time)
- POSIX time standard (IEEE 1003.1)
