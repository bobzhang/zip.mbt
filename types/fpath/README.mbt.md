# fpath - File Path Utilities

**Level**: 1  
**Package**: `bobzhang/zip/types/fpath`  
**Dependencies**: None

## Overview

The `fpath` package provides utilities for manipulating and normalizing file paths in ZIP archives. It ensures paths are in the proper Unix format and handles directory path conventions.

## Features

- **Unix Path Normalization**: Convert Windows `\` to Unix `/`
- **Directory Path Handling**: Ensure directories end with `/`
- **Path Sanitization**: Remove redundant separators and `.` components
- **Type Safety**: Fpath type alias for better API clarity

## API

### Types

```
pub typealias String as Fpath
```

File path type. Internally just a string, but provides semantic clarity.

### Functions

#### `fpath_ensure_unix(path : Fpath) -> Fpath`

Convert any path to Unix-style (forward slashes).

**Transformation:**
- `dir\subdir\file.txt` → `dir/subdir/file.txt`
- `dir/subdir/file.txt` → `dir/subdir/file.txt` (unchanged)

**Example:**
```moonbit
///|
test {
  let windows_path : Fpath = "C:\\Users\\name\\file.txt"
  let unix_path = ensure_unix(windows_path)
  @json.inspect(unix_path, content="C:/Users/name/file.txt")
}
```

#### `fpath_ensure_directoryness(path : Fpath) -> Fpath`

Ensure directory paths end with `/`.

**Transformation:**
- `mydir` → `mydir/`
- `mydir/` → `mydir/` (unchanged)
- `mydir/subdir` → `mydir/subdir/`

**Example:**
```
let dir = "src/main"
let dir_path = fpath_ensure_directoryness(dir)
// Result: "src/main/"
```

#### `fpath_sanitize(path : Fpath) -> Fpath`

Remove redundant path separators and normalize `.` components.

**Transformations:**
- `dir//subdir///file.txt` → `dir/subdir/file.txt`
- `dir/./subdir/./file.txt` → `dir/subdir/file.txt`
- `./dir/file.txt` → `dir/file.txt`

**Example:**
```
let messy_path = "src//./main///utils/./file.txt"
let clean_path = fpath_sanitize(messy_path)
// Result: "src/main/utils/file.txt"
```

## Usage Examples

### Creating ZIP-Compatible Paths

```
// Windows input
let user_path = "Documents\\Projects\\src\\main.mbt"

// Normalize for ZIP
let zip_path = fpath_ensure_unix(user_path)
let clean_path = fpath_sanitize(zip_path)
// Result: "Documents/Projects/src/main.mbt"
```

### Directory Handling

```
// Create directory entry
let dir_name = "src/utils"
let dir_path = fpath_ensure_directoryness(
  fpath_ensure_unix(
    fpath_sanitize(dir_name)
  )
)
// Result: "src/utils/"
```

### Path Pipeline

```
fn normalize_for_zip(path : String) -> Fpath {
  path
  |> fpath_sanitize
  |> fpath_ensure_unix
}

fn normalize_directory(path : String) -> Fpath {
  path
  |> normalize_for_zip
  |> fpath_ensure_directoryness
}

let file_path = normalize_for_zip("dir\\./subdir//file.txt")
// Result: "dir/subdir/file.txt"

let dir_path = normalize_directory("my\\project\\src")
// Result: "my/project/src/"
```

## ZIP Path Requirements

### Path Format
- **Separator**: Must use forward slash `/`
- **No Backslash**: Windows `\` not allowed
- **Directories**: Must end with `/`
- **Case**: Preserved (ZIP is case-preserving)
- **Encoding**: UTF-8 (when GP flag bit 11 set)

### Invalid Paths
ZIP archives should avoid:
- Absolute paths (`/home/user/file.txt`)
- Drive letters (`C:/file.txt`)
- Parent references (`../file.txt`)
- Null bytes or control characters

**Note:** This package doesn't validate security concerns. The main ZIP package should handle security validation.

## Path Normalization Rules

### Separator Normalization
```
Input:  "dir\\subdir\\file.txt"
Step 1: Replace '\' with '/'
Output: "dir/subdir/file.txt"
```

### Redundant Separator Removal
```
Input:  "dir///subdir//file.txt"
Step 1: Replace multiple '/' with single '/'
Output: "dir/subdir/file.txt"
```

### Dot Component Removal
```
Input:  "dir/./subdir/./file.txt"
Step 1: Remove '/.' components
Output: "dir/subdir/file.txt"
```

### Directory Slash Addition
```
Input:  "dir/subdir"
Step 1: Check if ends with '/'
Step 2: If not, append '/'
Output: "dir/subdir/"
```

## Common Patterns

### File Entry Path
```
fn make_file_path(raw_path : String) -> Fpath {
  raw_path
  |> fpath_sanitize      // Clean up
  |> fpath_ensure_unix   // Unix separators
}
```

### Directory Entry Path
```
fn make_dir_path(raw_path : String) -> Fpath {
  raw_path
  |> fpath_sanitize           // Clean up
  |> fpath_ensure_unix        // Unix separators
  |> fpath_ensure_directoryness  // Add trailing slash
}
```

### Full Normalization
```
fn normalize_zip_path(raw_path : String, is_dir : Bool) -> Fpath {
  let path = raw_path
    |> fpath_sanitize
    |> fpath_ensure_unix
  
  if is_dir {
    fpath_ensure_directoryness(path)
  } else {
    path
  }
}
```

## Implementation Notes

### String Operations
- **`ensure_unix`**: Simple character replacement (`\` → `/`)
- **`ensure_directoryness`**: String length check + append
- **`sanitize`**: Regex-like pattern replacement (simplified)

### Performance
- **Time**: O(n) where n is path length
- **Space**: O(n) for result string
- **No Allocation**: If path already normalized (depends on implementation)

### Edge Cases
- **Empty string**: Returns empty string (all functions)
- **Root `/`**: Preserved
- **Single slash `/`**: Preserved
- **Only dots `./././`**: Results in empty string (sanitize)

## Testing

Run tests with:
```bash
moon test types/fpath
```

Tests cover:
- Unix path conversion
- Directory path handling
- Path sanitization
- Edge cases (empty, root, special chars)
- Multiple transformations
- Idempotency (applying twice has same result)

## Dependencies

None - This is a Level 1 package with no external dependencies.

## Used By

- `types` (Level 2) - Re-exports fpath functions
- Main `zip` package - Via types re-exports
- Any package handling ZIP file paths

## Future Enhancements

Potential additions:
- Path validation (security checks)
- Absolute path detection
- Parent reference (`..`) handling
- Path component extraction
- Path joining/splitting
- Unicode normalization
- Max path length validation (ZIP limit: 65535)

## References

- [ZIP File Format Specification - File Names](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT)
  - Section 4.4.17: file name (length and content)
- POSIX path conventions
- Windows path conventions (for conversion)

## Notes

- **No Validation**: Functions don't validate path security or legality
- **Preserves Content**: Doesn't modify filename or extension
- **Case Sensitive**: Treats paths as case-sensitive (ZIP standard)
- **UTF-8**: Assumes UTF-8 encoding (set GP flag bit 11 in ZIP)
