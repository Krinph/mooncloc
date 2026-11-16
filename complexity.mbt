///|
/// Cyclomatic complexity analysis.
///
/// The scanner re-uses the same comment/string stripping rules as the line
/// counter, then counts control-flow keywords and boolean operators that
/// create branch points: `if`, `elif`, `for`, `while`, `loop`, `guard`,
/// `catch`, `match`, `case`, `when`, `switch`, `&&`, `||` and `?`.

///|
/// Scanner state while extracting code tokens.
priv enum ComplexityState {
  CNormal
  CBlock(Array[Char], Array[Char], Int32)
  CString(Array[Char], Bool)
}

///|
/// Compute the cyclomatic complexity of `text` (total number of branch
/// points across the whole file).
pub fn count_complexity(text : String, lang : LanguageDef) -> Int32 {
  if text.length() == 0 {
    return 0
  }
  let mut score = 0
  let mut state = ComplexityState::CNormal
  for line_view in split_lines(text) {
    let line = line_view.to_owned()
    let (next_state, tokens) = extract_tokens(line, lang, state)
    state = next_state
    for tok in tokens {
      if is_control_keyword(tok) {
        score = score + 1
      }
    }
  }
  score
}

///|
/// Extract the code tokens of one line: words and operators, with comments
/// and string literals removed.
fn extract_tokens(
  line : String,
  lang : LanguageDef,
  state : ComplexityState,
) -> (ComplexityState, Array[String]) {
  let chars = line.to_array()
  let result : Array[String] = []
  let mut i = 0
  let mut st = state
  while i < chars.length() {
    match st {
      ComplexityState::CBlock(start, end, depth) =>
        if matches_at(chars, i, end) {
          if depth == 1 {
            st = ComplexityState::CNormal
          } else {
            st = ComplexityState::CBlock(start, end, depth - 1)
          }
          i = i + end.length()
        } else if depth > 0 && matches_at(chars, i, start) {
          st = ComplexityState::CBlock(start, end, depth + 1)
          i = i + start.length()
        } else {
          i = i + 1
        }
      ComplexityState::CString(end, raw) =>
        if matches_at(chars, i, end) {
          st = ComplexityState::CNormal
          i = i + end.length()
        } else if !raw && chars[i] == '\\' && i + 1 < chars.length() {
          i = i + 2
        } else {
          i = i + 1
        }
      ComplexityState::CNormal =>
        match match_token(chars, i, lang) {
          TokenMatch::Multiline(start, end) => {
            st = ComplexityState::CString(end, false)
            i = i + start.length()
          }
          TokenMatch::Raw(start, end) => {
            st = ComplexityState::CString(end, true)
            i = i + start.length()
          }
          TokenMatch::Quote(q) => {
            let (consumed, multiline) = scan_string(chars, i, q, lang)
            i = i + consumed
            if multiline {
              st = ComplexityState::CString(q.to_string().to_array(), false)
            }
          }
          TokenMatch::Block(start, end) => {
            st = ComplexityState::CBlock(start, end, 1)
            i = i + start.length()
          }
          TokenMatch::LineComment => break
          TokenMatch::None =>
            if is_word_char(chars[i]) {
              // collect a word
              let mut j = i
              while j < chars.length() && is_word_char(chars[j]) {
                j = j + 1
              }
              result.push(StringView::from_iter(chars[i:j].iter()).to_owned())
              i = j
            } else if is_space_char(chars[i]) {
              i = i + 1
            } else {
              // collect an operator run
              let mut j = i
              while j < chars.length() &&
                    !is_word_char(chars[j]) &&
                    !is_space_char(chars[j]) {
                j = j + 1
              }
              result.push(StringView::from_iter(chars[i:j].iter()).to_owned())
              i = j
            }
        }
    }
  }
  (st, result)
}

///|
/// Is `tok` a control-flow keyword or boolean operator that adds a branch?
fn is_control_keyword(tok : String) -> Bool {
  tok == "if" ||
  tok == "elif" ||
  tok == "for" ||
  tok == "while" ||
  tok == "loop" ||
  tok == "guard" ||
  tok == "catch" ||
  tok == "match" ||
  tok == "case" ||
  tok == "when" ||
  tok == "switch" ||
  tok == "&&" ||
  tok == "||" ||
  tok == "?"
}
