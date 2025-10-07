///|
/// ZIP Archive - represents a complete ZIP file structure.
/// 
/// An Archive is the top-level container for a collection of files and directories
/// that can be serialized to/from the ZIP file format. Internally uses a Map for
/// O(log n) lookups by normalized file path.
/// 
/// Features:
/// - Preserves insertion order for deterministic output
/// - Supports both files and directories
/// - Path normalization and validation via Fpath
/// - JSON serialization for debugging/inspection
/// 
/// Usage example:
/// archive.empty() |> archive.add(member) |> archive.to_bytes()
struct Archive {
  members : Map[Fpath, Member] // Mutable map; iteration yields insertion order for deterministic ZIP output
}

///|
/// JSON serialization for Archive inspection and debugging.
/// 
/// Produces a JSON object with:
/// - "length": total number of members
/// - "members": array of [path, type] pairs in insertion order
/// 
/// Example output structure:
/// {"length": 3, "members": [["readme.txt", "File"], ["src/", "Dir"]]}
pub impl ToJson for Archive with to_json(self) {
  let members : Array[Json] = []
  for path, m in self.members { // insertion order
    match m.kind() {
      Dir => members.push([path, "Dir"])
      File(_f) => members.push([path, "File"])
    }
  }
  { "length": self.members.length(), "members": members }
}
