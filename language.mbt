///|
/// A language definition: how to recognize a file type, and how to strip
/// comments and string literals for accurate line counting.
///
/// - `extensions`: file extensions WITHOUT the leading dot.
/// - `filenames`: exact file names (Dockerfile, Makefile...).
/// - `line_comment`: markers that start a comment running to end of line.
/// - `block_comment`: `(start, end)` pairs for block comments.
/// - `nested_block`: whether block comments may nest (Rust, Haskell, OCaml...).
/// - `string_quotes`: single-character string delimiters that do not span
///   lines (C family).
/// - `multiline_quotes`: single-character delimiters that may span lines
///   (JS template literals, Go raw strings).
/// - `multiline_strings`: explicit `(start, end)` pairs (Python `"""`, MoonBit
///   `#| ... |#`).
/// - `raw_strings`: raw (no escape) string forms such as Python `r"..."`,
///   C# `@"..."` or Rust `r#"..."#`.
/// - `shebang_is_comment`: a leading `#!` line counts as a comment.
pub struct LanguageDef {
  name : String
  extensions : Array[String]
  filenames : Array[String]
  line_comment : Array[String]
  block_comment : Array[(String, String)]
  nested_block : Bool
  string_quotes : Array[Char]
  multiline_quotes : Array[Char]
  multiline_strings : Array[(String, String)]
  raw_strings : Array[(String, String)]
  shebang_is_comment : Bool
}

///|
/// Build a language definition. Omitted options fall back to their defaults
/// (empty arrays / false).
fn make_lang(
  name : String,
  extensions : Array[String],
  filenames? : Array[String],
  line_comment? : Array[String],
  block_comment? : Array[(String, String)],
  nested_block? : Bool,
  string_quotes? : Array[Char],
  multiline_quotes? : Array[Char],
  multiline_strings? : Array[(String, String)],
  raw_strings? : Array[(String, String)],
  shebang_is_comment? : Bool,
) -> LanguageDef {
  {
    name,
    extensions,
    filenames: filenames.unwrap_or_default(),
    line_comment: line_comment.unwrap_or_default(),
    block_comment: block_comment.unwrap_or_default(),
    nested_block: nested_block.unwrap_or_default(),
    string_quotes: string_quotes.unwrap_or_default(),
    multiline_quotes: multiline_quotes.unwrap_or_default(),
    multiline_strings: multiline_strings.unwrap_or_default(),
    raw_strings: raw_strings.unwrap_or_default(),
    shebang_is_comment: shebang_is_comment.unwrap_or_default(),
  }
}

///|
/// Look up a language by file extension (with or without the leading dot).
pub fn language_by_extension(ext : String) -> LanguageDef? {
  for lang in all_languages() {
    for candidate in lang.extensions {
      if candidate == ext || candidate == "." + ext {
        return Some(lang)
      }
    }
  }
  None
}

///|
/// Look up a language by exact file name (Dockerfile, Makefile...).
pub fn language_by_filename(name : String) -> LanguageDef? {
  for lang in all_languages() {
    for candidate in lang.filenames {
      if candidate == name {
        return Some(lang)
      }
    }
  }
  None
}

///|
/// The complete built-in language table.
pub fn all_languages() -> Array[LanguageDef] {
  [
    lang_moonbit(),
    lang_c(),
    lang_cpp(),
    lang_csharp(),
    lang_java(),
    lang_javascript(),
    lang_jsx(),
    lang_typescript(),
    lang_tsx(),
    lang_python(),
    lang_ruby(),
    lang_go(),
    lang_rust(),
    lang_swift(),
    lang_kotlin(),
    lang_php(),
    lang_lua(),
    lang_shell(),
    lang_sql(),
    lang_html(),
    lang_css(),
    lang_json(),
    lang_xml(),
    lang_yaml(),
    lang_toml(),
    lang_ini(),
    lang_markdown(),
    lang_dockerfile(),
    lang_zig(),
    lang_dart(),
    lang_haskell(),
    lang_ocaml(),
    lang_elixir(),
  ]
}

///|
fn lang_moonbit() -> LanguageDef {
  make_lang(
    "MoonBit",
    [".mbt"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    nested_block=true,
    string_quotes=['"', '\''],
    multiline_strings=[("#|", "|#")],
  )
}

///|
fn lang_c() -> LanguageDef {
  make_lang(
    "C",
    [".c", ".h"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
  )
}

///|
fn lang_cpp() -> LanguageDef {
  make_lang(
    "C++",
    [".cpp", ".cc", ".cxx", ".hpp", ".hh", ".hxx", ".ino"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
  )
}

///|
fn lang_csharp() -> LanguageDef {
  make_lang(
    "C#",
    [".cs"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
    raw_strings=[("@\"", "\"")],
  )
}

///|
fn lang_java() -> LanguageDef {
  make_lang(
    "Java",
    [".java"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
  )
}

///|
fn lang_javascript() -> LanguageDef {
  make_lang(
    "JavaScript",
    [".js", ".mjs", ".cjs"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
    multiline_quotes=['`'],
  )
}

///|
fn lang_jsx() -> LanguageDef {
  make_lang(
    "JSX",
    [".jsx"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
    multiline_quotes=['`'],
  )
}

///|
fn lang_typescript() -> LanguageDef {
  make_lang(
    "TypeScript",
    [".ts"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
    multiline_quotes=['`'],
  )
}

///|
fn lang_tsx() -> LanguageDef {
  make_lang(
    "TSX",
    [".tsx"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
    multiline_quotes=['`'],
  )
}

///|
fn lang_python() -> LanguageDef {
  make_lang(
    "Python",
    [".py", ".pyw"],
    line_comment=["#"],
    string_quotes=['"', '\''],
    multiline_strings=[("\"\"\"", "\"\"\""), ("'''", "'''")],
    raw_strings=[("r\"", "\""), ("r'", "'"), ("R\"", "\""), ("R'", "'")],
    shebang_is_comment=true,
  )
}

///|
fn lang_ruby() -> LanguageDef {
  make_lang(
    "Ruby",
    [".rb", ".rake"],
    line_comment=["#"],
    block_comment=[("=begin", "=end")],
    string_quotes=['"', '\''],
    shebang_is_comment=true,
  )
}

///|
fn lang_go() -> LanguageDef {
  make_lang(
    "Go",
    [".go"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    string_quotes=['"'],
    multiline_quotes=['`'],
  )
}

///|
fn lang_rust() -> LanguageDef {
  make_lang(
    "Rust",
    [".rs"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    nested_block=true,
    string_quotes=['"', '\''],
    raw_strings=[("r#\"", "\"#"), ("r\"", "\"")],
  )
}

///|
fn lang_swift() -> LanguageDef {
  make_lang(
    "Swift",
    [".swift"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
    multiline_strings=[("\"\"\"", "\"\"\"")],
  )
}

///|
fn lang_kotlin() -> LanguageDef {
  make_lang(
    "Kotlin",
    [".kt", ".kts"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
    multiline_strings=[("\"\"\"", "\"\"\"")],
  )
}

///|
fn lang_php() -> LanguageDef {
  make_lang(
    "PHP",
    [".php"],
    line_comment=["//", "#"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
  )
}

///|
fn lang_lua() -> LanguageDef {
  make_lang(
    "Lua",
    [".lua"],
    line_comment=["--"],
    block_comment=[("--[[", "]]")],
    string_quotes=['"', '\''],
    multiline_strings=[("[[", "]]")],
  )
}

///|
fn lang_shell() -> LanguageDef {
  make_lang(
    "Shell",
    [".sh", ".bash", ".zsh", ".fish", ".ksh"],
    line_comment=["#"],
    string_quotes=['"', '\''],
    shebang_is_comment=true,
  )
}

///|
fn lang_sql() -> LanguageDef {
  make_lang(
    "SQL",
    [".sql"],
    line_comment=["--"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
  )
}

///|
fn lang_html() -> LanguageDef {
  make_lang(
    "HTML",
    [".html", ".htm", ".xhtml", ".vue"],
    block_comment=[("<!--", "-->")],
    string_quotes=['"', '\''],
  )
}

///|
fn lang_css() -> LanguageDef {
  make_lang(
    "CSS",
    [".css", ".scss", ".less", ".sass"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
  )
}

///|
fn lang_json() -> LanguageDef {
  make_lang("JSON", [".json", ".jsonc"], string_quotes=['"'])
}

///|
fn lang_xml() -> LanguageDef {
  make_lang(
    "XML",
    [".xml", ".svg", ".plist", ".xsd", ".xsl", ".xslt"],
    block_comment=[("<!--", "-->")],
    string_quotes=['"', '\''],
  )
}

///|
fn lang_yaml() -> LanguageDef {
  make_lang("YAML", [".yml", ".yaml"], line_comment=["#"], string_quotes=[
    '"', '\'',
  ])
}

///|
fn lang_toml() -> LanguageDef {
  make_lang("TOML", [".toml"], line_comment=["#"], string_quotes=['"', '\''])
}

///|
fn lang_ini() -> LanguageDef {
  make_lang(
    "INI",
    [".ini", ".cfg", ".conf", ".properties"],
    line_comment=["#", ";"],
    string_quotes=['"', '\''],
  )
}

///|
fn lang_markdown() -> LanguageDef {
  make_lang("Markdown", [".md", ".markdown", ".mdown"], block_comment=[
    ("<!--", "-->"),
  ])
}

///|
fn lang_dockerfile() -> LanguageDef {
  make_lang(
    "Dockerfile",
    [],
    filenames=["Dockerfile", "Containerfile"],
    line_comment=["#"],
    string_quotes=['"', '\''],
  )
}

///|
fn lang_zig() -> LanguageDef {
  make_lang("Zig", [".zig"], line_comment=["//"], string_quotes=['"', '\''])
}

///|
fn lang_dart() -> LanguageDef {
  make_lang(
    "Dart",
    [".dart"],
    line_comment=["//"],
    block_comment=[("/*", "*/")],
    string_quotes=['"', '\''],
    multiline_strings=[("\"\"\"", "\"\"\""), ("'''", "'''")],
  )
}

///|
fn lang_haskell() -> LanguageDef {
  make_lang(
    "Haskell",
    [".hs", ".lhs"],
    line_comment=["--"],
    block_comment=[("{-", "-}")],
    nested_block=true,
    string_quotes=['"', '\''],
  )
}

///|
fn lang_ocaml() -> LanguageDef {
  make_lang(
    "OCaml",
    [".ml", ".mli"],
    block_comment=[("(*", "*)")],
    nested_block=true,
    string_quotes=['"', '\''],
  )
}

///|
fn lang_elixir() -> LanguageDef {
  make_lang(
    "Elixir",
    [".ex", ".exs"],
    line_comment=["#"],
    string_quotes=['"', '\''],
    shebang_is_comment=true,
  )
}
