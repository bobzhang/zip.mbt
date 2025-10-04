///|
/// ZIP Archive - represents a complete ZIP file
struct Archive {
  members : @immut/sorted_map.SortedMap[Fpath, Member] // Maps path to member
}
