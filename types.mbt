///|
/// ZIP Archive - represents a complete ZIP file
struct Archive {
  members : @immut/sorted_map.SortedMap[Fpath, Member] // Maps path to member
}

///|
pub impl ToJson for Archive with to_json(self) {
  let members : Array[Json] = []
  for path, m in self.members {
    match m.kind() {
      Dir => members.push([path, "Dir"])
      File(_f) => members.push([path, "File"])
    }
  }
  { "length": self.members.length(), "members": members }
}
