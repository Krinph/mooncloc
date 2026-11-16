///|
/// White-box unit tests for the line tokenizer: comments, strings and line
/// classification across many languages.

///|
test "moonbit: line comments, block comments, multiline strings" {
  let lang = language_by_extension("mbt").unwrap()
  let src =
    #|fn main {
    #|  // line comment
    #|  let s = #|multi
    #|line string|#
    #|  let t = "string with // inside"
    #|  /* block
    #|     comment */
    #|  println(t)
    #|}
  let c = count_text(src, lang, true)
  assert_eq(c.code, 6)
  assert_eq(c.comment, 3)
  assert_eq(c.blank, 0)
}

///|
test "c: block comment spanning lines" {
  let lang = language_by_extension("c").unwrap()
  let src =
    #|int main(void) {
    #|    /* start
    #|       middle
    #|    end */
    #|    return 0; // trailing
    #|}
  let c = count_text(src, lang, true)
  assert_eq(c.code, 3)
  assert_eq(c.comment, 3)
  assert_eq(c.mixed, 1)
}

///|
test "c: comment markers inside strings are ignored" {
  let lang = language_by_extension("c").unwrap()
  let src =
    #|const char* a = "http://example.com";
    #|const char* b = "/* not a comment */";
    #|int x = 1; // real comment
  let c = count_text(src, lang, true)
  assert_eq(c.code, 3)
  assert_eq(c.comment, 0)
  assert_eq(c.mixed, 1)
}

///|
test "python: triple-quoted strings and raw strings" {
  let lang = language_by_extension("py").unwrap()
  let src =
    #|#!/usr/bin/env python3
    #|"""module docstring
    #|across lines"""
    #|import re
    #|pat = r"\d+//x"  # regex is not a comment
    #|def f():
    #|    pass
  let c = count_text(src, lang, true)
  assert_eq(c.code, 6)
  assert_eq(c.comment, 1)
  assert_eq(c.mixed, 1)
}

///|
test "python: docstring counting" {
  let lang = language_by_extension("py").unwrap()
  let src =
    #|def f():
    #|    """doc"""
    #|    return 1
  let c = count_text(src, lang, true)
  assert_eq(c.code, 3)
  assert_eq(c.comment, 0)
}

///|
test "javascript: template literals span lines" {
  let lang = language_by_extension("js").unwrap()
  let src =
    #|const html = `
    #|<div>// not a comment</div>
    #|`;
    #|// comment
    #|const x = 1;
  let c = count_text(src, lang, true)
  assert_eq(c.code, 4)
  assert_eq(c.comment, 1)
}

///|
test "rust: nested block comments and raw strings" {
  let lang = language_by_extension("rs").unwrap()
  let src =
    #|/* outer /* inner */ still outer */
    #|let s = r#"raw "quoted" text"#;
    #|// line
    #|fn main() {}
  let c = count_text(src, lang, true)
  assert_eq(c.code, 2)
  assert_eq(c.comment, 2)
}

///|
test "shell: shebang and comments" {
  let lang = language_by_extension("sh").unwrap()
  let src =
    #|#!/bin/bash
    #|# comment
    #|echo "hello # world"
    #|echo $((2 + 3))
  let c = count_text(src, lang, true)
  assert_eq(c.code, 2)
  assert_eq(c.comment, 2)
}

///|
test "lua: long strings and long comments" {
  let lang = language_by_extension("lua").unwrap()
  let src =
    #|--[[ block
    #|comment ]]
    #|local s = [[long
    #|string]]
    #|local t = "a--b" -- real comment
    #|print(t)
  let c = count_text(src, lang, true)
  assert_eq(c.code, 4)
  assert_eq(c.comment, 2)
  assert_eq(c.mixed, 1)
}

///|
test "html: comments" {
  let lang = language_by_extension("html").unwrap()
  let src =
    #|<!-- header -->
    #|<h1>Title</h1>
    #|<!--
    #|multi line
    #|-->
  let c = count_text(src, lang, true)
  assert_eq(c.code, 1)
  assert_eq(c.comment, 4)
}

///|
test "blank lines and mixed lines" {
  let lang = language_by_extension("mbt").unwrap()
  let src =
    #|
    #|fn main {
    #|
    #|  let x = 1 // trailing comment
    #|
  let c = count_text(src, lang, true)
  assert_eq(c.code, 2)
  assert_eq(c.comment, 0)
  assert_eq(c.mixed, 1)
  assert_eq(c.blank, 2)
  // with mixed counted as comments
  let c2 = count_text(src, lang, false)
  assert_eq(c2.code, 1)
  assert_eq(c2.comment, 1)
}

///|
test "empty text and trailing newline" {
  let lang = language_by_extension("mbt").unwrap()
  let c1 = count_text("", lang, true)
  assert_eq(c1.code, 0)
  assert_eq(c1.blank, 0)
  let c2 = count_text("a\n", lang, true)
  assert_eq(c2.code, 1)
  assert_eq(c2.blank, 0)
  let c3 = count_text("a\n\n", lang, true)
  assert_eq(c3.code, 1)
  assert_eq(c3.blank, 1)
}
