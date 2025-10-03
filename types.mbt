///|
/// ZIP Archive - represents a complete ZIP file
struct Archive {
  members : @immut/sorted_map.SortedMap[String, Member] // Maps path to member
}
