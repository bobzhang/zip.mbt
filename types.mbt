///|
/// ZIP Archive - represents a complete ZIP file
struct Archive {
  members : Map[Fpath, Member] // Mutable map; we enforce sorted order at iteration time
}

///|
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
