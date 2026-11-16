///|
/// White-box unit tests for the gitignore-style exclude rules.

///|
test "ignore: unanchored patterns match at any depth" {
  let rules = IgnoreRules::new(["target"])
  assert_eq(rules.ignores("target"), true)
  assert_eq(rules.ignores("src/target"), true)
  assert_eq(rules.ignores("src/target/gen.mbt"), true)
  assert_eq(rules.ignores("src/main.mbt"), false)
  assert_eq(rules.ignores("src/targeted.mbt"), false)
}

///|
test "ignore: directory patterns ignore their contents" {
  let rules = IgnoreRules::new(["build/"])
  assert_eq(rules.ignores("build"), true)
  assert_eq(rules.ignores("build/out.exe"), true)
  assert_eq(rules.ignores("a/b/build/c.txt"), true)
  assert_eq(rules.ignores("a/b/notbuild/c.txt"), false)
}

///|
test "ignore: anchored patterns are relative to the root" {
  let rules = IgnoreRules::new(["src/generated"])
  assert_eq(rules.ignores("src/generated"), true)
  assert_eq(rules.ignores("src/generated/x.mbt"), false)
  assert_eq(rules.ignores("other/src/generated"), false)
}

///|
test "ignore: double star matches any number of segments" {
  let rules = IgnoreRules::new(["**/test"])
  assert_eq(rules.ignores("test"), true)
  assert_eq(rules.ignores("a/b/test"), true)
  let rules2 = IgnoreRules::new(["a/**/b"])
  assert_eq(rules2.ignores("a/b"), true)
  assert_eq(rules2.ignores("a/x/y/b"), true)
  assert_eq(rules2.ignores("a/x/y/c"), false)
}

///|
test "ignore: wildcard characters within a segment" {
  let rules = IgnoreRules::new(["*.tmp"])
  assert_eq(rules.ignores("file.tmp"), true)
  assert_eq(rules.ignores("a/b/file.tmp"), true)
  assert_eq(rules.ignores("file.txt"), false)
  let rules2 = IgnoreRules::new(["file?.txt"])
  assert_eq(rules2.ignores("file1.txt"), true)
  assert_eq(rules2.ignores("file12.txt"), false)
}

///|
test "ignore: empty rule list ignores nothing" {
  let rules = IgnoreRules::new([])
  assert_eq(rules.ignores("anything.txt"), false)
}
