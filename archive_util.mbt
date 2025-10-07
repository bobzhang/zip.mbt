///|
/// Create an empty archive
pub fn Archive::empty() -> Archive {
  { members: {} }
}

///|
/// Check if archive is empty
pub fn Archive::is_empty(self : Archive) -> Bool {
  self.members.is_empty()
}

///|
/// Get the number of members in the archive
pub fn Archive::member_count(self : Archive) -> Int {
  self.members.length()
}

///|
/// Check if archive has a member with the given path
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
