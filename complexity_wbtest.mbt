///|
/// White-box unit tests for the cyclomatic complexity analyzer.

///|
test "complexity: control flow keywords" {
  let lang = language_by_extension("mbt").unwrap()
  let src =
    #|fn f(x: Int) -> Int {
    #|  if x > 0 {
    #|    return 1
    #|  } else if x < 0 {
    #|    return -1
    #|  }
    #|  match x {
    #|    0 => 0
    #|    _ => 2
    #|  }
    #|  for i in 0..10 {
    #|    let y = i && true
    #|  }
    #|}
  let cx = count_complexity(src, lang)
  // if + elif + match + for + && = 5
  assert_eq(cx, 5)
}

///|
test "complexity: keywords in comments and strings do not count" {
  let lang = language_by_extension("mbt").unwrap()
  let src =
    #|// if for while match
    #|let s = "loop guard catch"
    #|let x = 1
  assert_eq(count_complexity(src, lang), 0)
}

///|
test "complexity: boolean operators and ternary in C" {
  let lang = language_by_extension("c").unwrap()
  let src =
    #|int f(int a, int b) {
    #|  if (a && b || a) { return a ? 1 : 2; }
    #|  while (a) { a--; }
    #|  return 0;
    #|}
  // if + && + || + ? + while = 5
  assert_eq(count_complexity(src, lang), 5)
}

///|
test "complexity: python control flow" {
  let lang = language_by_extension("py").unwrap()
  let src =
    #|def f(items):
    #|    for item in items:
    #|        if item is None:
    #|            continue
    #|        elif item == 0:
    #|            break
    #|    while True:
    #|        pass
  // for + if + elif + while = 4
  assert_eq(count_complexity(src, lang), 4)
}

///|
test "complexity: empty and comment-only input" {
  let lang = language_by_extension("mbt").unwrap()
  assert_eq(count_complexity("", lang), 0)
  assert_eq(count_complexity("// nothing\n", lang), 0)
}
