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
/// Fold over all members in lexicographic path order
pub fn[T] Archive::fold(self : Archive, f : (Member, T) -> T, init : T) -> T {
  // Collect keys and sort lexicographically to preserve previous semantics
  let keys : Array[Fpath] = []
  for k, _ in self.members {
    keys.push(k)
  }
  // Simple insertion sort (archives are usually small)
  for i = 1; i < keys.length(); i = i + 1 {
    let key = keys[i]
    let mut j = i - 1
    while j >= 0 && keys[j].to_string() > key.to_string() {
      keys[j + 1] = keys[j]
      j = j - 1
    }
    keys[j + 1] = key
  }
  let mut acc = init
  for k in keys {
    acc = f(self.members[k], acc)
  }
  acc
}

///|
/// Convert archive to an array of members (sorted by path)
pub fn Archive::to_array(self : Archive) -> Array[Member] {
  let result : Array[Member] = []
  // Reuse sorted iteration
  let keys : Array[Fpath] = []
  for k, _ in self.members {
    keys.push(k)
  }
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
    result.push(self.members[k])
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
