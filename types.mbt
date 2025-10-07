///|
/// ZIP Archive - represents a complete ZIP file
struct Archive {
  members : Map[Fpath, Member] // Mutable map; we enforce sorted order at iteration time
}

///|
pub impl ToJson for Archive with to_json(self) {
  let members : Array[Json] = []
  let keys : Array[Fpath] = []
  for path, _ in self.members {
    keys.push(path)
  }
  // insertion sort
  for i = 1; i < keys.length(); i = i + 1 {
    let key = keys[i]
    let mut j = i - 1
    while j >= 0 && keys[j].to_string() > key.to_string() {
      keys[j + 1] = keys[j]
      j = j - 1
    }
    keys[j + 1] = key
  }
  for k in keys {
    let m = self.members[k]
    match m.kind() {
      Dir => members.push([k, "Dir"])
      File(_f) => members.push([k, "File"])
    }
  }
  { "length": self.members.length(), "members": members }
}
