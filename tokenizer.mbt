///|
/// The result of counting one file: how many lines fall into each category.
pub struct CountResult {
  mut code : Int32
  mut comment : Int32
  mut blank : Int32
  /// Lines that contain both code and a trailing comment (also included in
  /// `code` or `comment` depending on `CountOptions.count_mixed_as_code`).
  mut mixed : Int32
}

///|
pub fn CountResult::default() -> CountResult {
  { code: 0, comment: 0, blank: 0, mixed: 0, }
}

///|
/// Per-line classification result.
pub enum LineKind {
  Blank
  Code
  Comment
  Mixed
}

///|
/// Scanner state that persists across lines (block comments and multi-line
/// string literals).
priv enum ScanState {
  Normal
  BlockComment(Array[Char], Array[Char], Int32)
  InString(Array[Char], Bool)
}

///|
/// A token found by the scanner at the current position.
priv enum TokenMatch {
  None
  Multiline(Array[Char], Array[Char])
  Raw(Array[Char], Array[Char])
  Quote(Char)
  Block(Array[Char], Array[Char])
  LineComment
}

///|
/// Count lines in `text` using the comment/string rules of `lang`.
/// Mixed lines (code + comment) are counted as code when `mixed_as_code` is
/// true, otherwise as comments.
pub fn count_text(
  text : String,
  lang : LanguageDef,
  mixed_as_code : Bool,
) -> CountResult {
  if text.length() == 0 {
    return CountResult::default()
  }
  let result = CountResult::default()
  let mut state = ScanState::Normal
  let mut first = true
  for line_view in split_lines(text) {
    let line = line_view.to_owned()
    let (kind, next_state) = classify_line(line, lang, state, first)
    state = next_state
    match kind {
      LineKind::Blank => result.blank = result.blank + 1
      LineKind::Code => result.code = result.code + 1
      LineKind::Comment => result.comment = result.comment + 1
      LineKind::Mixed => {
        result.mixed = result.mixed + 1
        if mixed_as_code {
          result.code = result.code + 1
        } else {
          result.comment = result.comment + 1
        }
      }
    }
    first = false
  }
  result
}

///|
/// Classify a single line, carrying the scanner state in and out.
fn classify_line(
  line : String,
  lang : LanguageDef,
  state : ScanState,
  is_first : Bool,
) -> (LineKind, ScanState) {
  let chars = line.to_array()
  // A shebang line (`#!/...`) is a comment for scripting languages.
  if is_first &&
    lang.shebang_is_comment &&
    matches_at(chars, 0, "#!".to_array()) {
    return (LineKind::Comment, state)
  }
  let mut i = 0
  let mut has_code = false
  let mut has_comment = false
  let mut st = state
  while i < chars.length() {
    match st {
      ScanState::BlockComment(start, end, depth) => {
        has_comment = true
        if matches_at(chars, i, end) {
          if depth == 1 {
            st = ScanState::Normal
          } else {
            st = ScanState::BlockComment(start, end, depth - 1)
          }
          i = i + end.length()
        } else if depth > 0 && matches_at(chars, i, start) {
          st = ScanState::BlockComment(start, end, depth + 1)
          i = i + start.length()
        } else {
          i = i + 1
        }
      }
      ScanState::InString(end, raw) => {
        has_code = true
        if matches_at(chars, i, end) {
          st = ScanState::Normal
          i = i + end.length()
        } else if !raw && chars[i] == '\\' && i + 1 < chars.length() {
          i = i + 2
        } else {
          i = i + 1
        }
      }
      ScanState::Normal =>
        match match_token(chars, i, lang) {
          TokenMatch::Multiline(start, end) => {
            has_code = true
            st = ScanState::InString(end, false)
            i = i + start.length()
          }
          TokenMatch::Raw(start, end) => {
            has_code = true
            st = ScanState::InString(end, true)
            i = i + start.length()
          }
          TokenMatch::Quote(q) => {
            has_code = true
            let (consumed, multiline) = scan_string(chars, i, q, lang)
            i = i + consumed
            if multiline {
              st = ScanState::InString(q.to_string().to_array(), false)
            }
          }
          TokenMatch::Block(start, end) => {
            has_comment = true
            st = ScanState::BlockComment(start, end, 1)
            i = i + start.length()
          }
          TokenMatch::LineComment => {
            has_comment = true
            break
          }
          TokenMatch::None =>
            if is_space_char(chars[i]) {
              i = i + 1
            } else {
              has_code = true
              i = i + 1
            }
        }
    }
  }
  let kind = if has_code && has_comment {
    LineKind::Mixed
  } else if has_code {
    LineKind::Code
  } else if has_comment {
    LineKind::Comment
  } else {
    LineKind::Blank
  }
  (kind, st)
}

///|
/// Find the token starting at `pos`, checking longer markers first.
fn match_token(
  chars : Array[Char],
  pos : Int32,
  lang : LanguageDef,
) -> TokenMatch {
  match match_multiline_start(chars, pos, lang) {
    Some((start, end)) => return TokenMatch::Multiline(start, end)
    None => ()
  }
  match match_raw_start(chars, pos, lang) {
    Some((start, end)) => return TokenMatch::Raw(start, end)
    None => ()
  }
  match match_quote(chars, pos, lang) {
    Some(q) => return TokenMatch::Quote(q)
    None => ()
  }
  match match_block_start(chars, pos, lang) {
    Some((start, end)) => return TokenMatch::Block(start, end)
    None => ()
  }
  match match_line_comment(chars, pos, lang) {
    Some(_) => return TokenMatch::LineComment
    None => ()
  }
  TokenMatch::None
}

///|
/// Scan a single-quoted string starting at `pos` (which holds `quote`).
/// Returns how many characters were consumed and whether the string is still
/// open (multi-line quote that did not close on this line).
fn scan_string(
  chars : Array[Char],
  pos : Int32,
  quote : Char,
  lang : LanguageDef,
) -> (Int32, Bool) {
  let mut i = pos + 1
  while i < chars.length() {
    if chars[i] == '\\' && i + 1 < chars.length() {
      i = i + 2
    } else if chars[i] == quote {
      return (i - pos + 1, false)
    } else {
      i = i + 1
    }
  }
  let multiline = lang.multiline_quotes.contains(quote)
  (chars.length() - pos, multiline)
}

///|
fn match_quote(chars : Array[Char], pos : Int32, lang : LanguageDef) -> Char? {
  let c = chars[pos]
  if lang.multiline_quotes.contains(c) {
    return Some(c)
  }
  if lang.string_quotes.contains(c) {
    return Some(c)
  }
  None
}

///|
fn match_multiline_start(
  chars : Array[Char],
  pos : Int32,
  lang : LanguageDef,
) -> (Array[Char], Array[Char])? {
  for (start, end) in lang.multiline_strings {
    if matches_at(chars, pos, start.to_array()) {
      return Some((start.to_array(), end.to_array()))
    }
  }
  None
}

///|
fn match_raw_start(
  chars : Array[Char],
  pos : Int32,
  lang : LanguageDef,
) -> (Array[Char], Array[Char])? {
  for (start, end) in lang.raw_strings {
    if matches_at(chars, pos, start.to_array()) {
      return Some((start.to_array(), end.to_array()))
    }
  }
  None
}

///|
fn match_block_start(
  chars : Array[Char],
  pos : Int32,
  lang : LanguageDef,
) -> (Array[Char], Array[Char])? {
  for (start, end) in lang.block_comment {
    if matches_at(chars, pos, start.to_array()) {
      return Some((start.to_array(), end.to_array()))
    }
  }
  None
}

///|
fn match_line_comment(
  chars : Array[Char],
  pos : Int32,
  lang : LanguageDef,
) -> Array[Char]? {
  for marker in lang.line_comment {
    if matches_at(chars, pos, marker.to_array()) {
      return Some(marker.to_array())
    }
  }
  None
}
