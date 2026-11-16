///|
/// Shared helpers for the line scanner and the complexity analyzer.

///|
/// Does `chars[pos:]` start with `marker`?
fn matches_at(chars : Array[Char], pos : Int32, marker : Array[Char]) -> Bool {
  if pos + marker.length() > chars.length() {
    return false
  }
  let mut j = 0
  while j < marker.length() {
    if chars[pos + j] != marker[j] {
      return false
    }
    j = j + 1
  }
  true
}

///|
fn is_space_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

///|

///|
fn is_word_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_'
}

///|
/// Split text into physical lines. A single trailing newline does not create
/// an extra empty line, but an extra blank line at the end of the file does.
fn split_lines(text : String) -> Iter[StringView] {
  if text.has_suffix("\n") {
    text[:text.length() - 1].to_owned().split("\n")
  } else {
    text.split("\n")
  }
}
