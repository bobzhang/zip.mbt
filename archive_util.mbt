///|
/// Archive utility functions for ZIP archive management.
/// 
/// These functions provide convenient operations for working with Archive collections,
/// including creation, querying, modification, and iteration. Archives use Maps
/// internally for O(log n) lookup by file path (Fpath keys).

///|
/// Create an empty archive with no members.
/// Returns a fresh Archive ready for file additions.
pub fn Archive::empty() -> Archive {
  { members: {} }
}

///|
/// Check if archive contains any members (files or directories).
pub fn Archive::is_empty(self : Archive) -> Bool {
  self.members.is_empty()
}

///|
/// Get the total count of members (files + directories) in this archive.
pub fn Archive::member_count(self : Archive) -> Int {
  self.members.length()
}

///|
/// Test whether archive contains a member at the specified path.
/// Case-sensitive path comparison using normalized Fpath.
pub fn Archive::mem(self : Archive, path : Fpath) -> Bool {
  self.members.contains(path)
}

///|
/// Find a member by path
pub fn Archive::find(self : Archive, path : Fpath) -> Member? {
  self.members.get(path)
}

///|
/// Add a member to the archive (replaces if path already exists)
pub fn Archive::add(self : Archive, m : Member) -> Unit {
  self.members[m.path()] = m
}

///|
/// Remove a member from the archive by path
pub fn Archive::remove(self : Archive, path : Fpath) -> Unit {
  self.members.remove(path)
}

///|
/// Fold over members in insertion order (map iteration order)
pub fn[T] Archive::fold(self : Archive, f : (Member, T) -> T, init : T) -> T {
  let mut acc = init
  for _k, v in self.members { // rely on insertion order of Map
    acc = f(v, acc)
  }
  acc
}

///|
/// Convert archive to an array of members (in insertion order)
pub fn Archive::to_array(self : Archive) -> Array[Member] {
  let result : Array[Member] = []
  for _k, v in self.members {
    result.push(v)
  }
  result
}

///|
/// Convert archive to a SortedMap from path to member
pub fn Archive::to_map(self : Archive) -> Map[Fpath, Member] {
  self.members
}

///|
/// Create archive from a SortedMap
/// Warning: Assumes each key k maps to member m with Member::path(m) == k
pub fn Archive::of_map(map : Map[Fpath, Member]) -> Archive {
  { members: map }
}
