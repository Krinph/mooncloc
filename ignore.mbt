///|
/// Gitignore-style exclude rules.
///
/// Supported pattern syntax (a practical subset of `.gitignore`):
///
/// - `*` matches any run of characters within one path segment
/// - `?` matches exactly one character within one path segment
/// - `**` matches any number of path segments
/// - a trailing `/` marks a directory pattern
/// - a pattern without `/` matches at any depth (any suffix of the path)
/// - a pattern with `/` is anchored to the scan root

///|
pub struct IgnoreRules {
  patterns : Array[String]
}

///|
pub fn IgnoreRules::new(patterns : Array[String]) -> IgnoreRules {
  { patterns, }
}

///|
/// Does this rule set ignore `path` (relative to the scan root, `/`-separated)?
pub fn IgnoreRules::ignores(self : IgnoreRules, path : String) -> Bool {
  let normalized = normalize_path(path)
  let segs = segments(normalized)
  if segs.length() == 0 {
    return false
  }
  for pattern in self.patterns {
    let p = normalize_path(pattern)
    let dir_only = p.has_suffix("/")
    let pat_segs = segments(p)
    if pat_segs.length() == 0 {
      continue
    }
    let anchored = !dir_only && p.contains("/")
    if anchored {
      if match_segments(pat_segs, 0, segs, 0) {
        return true
      }
    } else {
      // Unanchored pattern (with or without a trailing slash): matches any
      // contiguous run of segments, so ignoring a directory also ignores
      // everything under it.
      for start = 0; start < segs.length(); start = start + 1 {
        for end = start + 1; end <= segs.length(); end = end + 1 {
          let sub = segs[start:end].to_owned()
          if match_segments(pat_segs, 0, sub, 0) {
            return true
          }
        }
      }
    }
  }
  false
}

///|
/// Match `pat[pi:]` against `text[ti:]`, segment by segment, supporting `**`.
fn match_segments(
  pat : Array[String],
  pi : Int32,
  text : Array[String],
  ti : Int32,
) -> Bool {
  if pi == pat.length() {
    return ti == text.length()
  }
  if pat[pi] == "**" {
    for k = ti; k <= text.length(); k = k + 1 {
      if match_segments(pat, pi + 1, text, k) {
        return true
      }
    }
    return false
  }
  if ti >= text.length() {
    return false
  }
  if !glob_match(pat[pi], text[ti]) {
    return false
  }
  match_segments(pat, pi + 1, text, ti + 1)
}

///|
/// Match a single segment pattern (no `/`) against a single segment.
/// Supports `*` and `?`.
fn glob_match(pattern : String, text : String) -> Bool {
  let pat = pattern.to_array()
  let t = text.to_array()
  match_segment(pat, 0, t, 0)
}

///|
fn match_segment(
  pat : Array[Char],
  pi : Int32,
  text : Array[Char],
  ti : Int32,
) -> Bool {
  if pi == pat.length() {
    return ti == text.length()
  }
  match pat[pi] {
    '*' => {
      for k = ti; k <= text.length(); k = k + 1 {
        if match_segment(pat, pi + 1, text, k) {
          return true
        }
      }
      false
    }
    '?' => {
      if ti >= text.length() {
        return false
      }
      match_segment(pat, pi + 1, text, ti + 1)
    }
    c => {
      if ti >= text.length() {
        return false
      }
      if text[ti] != c {
        return false
      }
      match_segment(pat, pi + 1, text, ti + 1)
    }
  }
}

///|
/// Split a path into segments. Leading/trailing slashes and duplicate
/// separators are ignored.
fn segments(path : String) -> Array[String] {
  let result : Array[String] = []
  for part in path.split("/") {
    let s = part.to_owned()
    if s.length() > 0 {
      result.push(s)
    }
  }
  result
}

///|
fn normalize_path(path : String) -> String {
  let s = path.replace_all(old="\\", new="/")
  s
}
