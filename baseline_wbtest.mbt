///|
/// White-box tests for the temporal quality gate: snapshots, the TokeiMBT
/// reuse bridge, diffs and gate policies.
fn snap(files : Array[SnapshotFile], source : String) -> Snapshot {
  { source, files, }
}

///|
fn file(
  path : String,
  code : Int32,
  comment : Int32,
  cx : Int32,
) -> SnapshotFile {
  { path, language: "MoonBit", code, comment, blank: 1, complexity: cx, }
}

///|
test "baseline: snapshot from counts and normalize path" {
  let counts = [
    {
      path: "./src/a.mbt",
      language: "MoonBit",
      blank: 1,
      comment: 2,
      code: 10,
      mixed: 0,
      complexity: 3,
    },
  ]
  let s = snapshot_from_counts(counts)
  assert_eq(s.source, "mooncloc")
  assert_eq(s.files[0].path, "src/a.mbt")
  assert_eq(s.files[0].complexity, 3)
}

///|
test "baseline: snapshot JSON round-trip" {
  let s = snap([file("a.mbt", 10, 2, 3), file("b.mbt", 5, 1, 0)], "mooncloc")
  let text = snapshot_to_json(s)
  let back = snapshot_from_json(text).unwrap()
  assert_eq(back.source, "mooncloc")
  assert_eq(back.files.length(), 2)
  assert_eq(back.files[0].path, "a.mbt")
  assert_eq(back.files[0].code, 10)
  assert_eq(back.files[1].complexity, 0)
}

///|
test "baseline: TokeiMBT JSON import is accepted (reuse bridge)" {
  let text = "{\"Rust\":{\"blanks\":1,\"comments\":2,\"code\":10,\"reports\":[{\"stats\":{\"blanks\":1,\"code\":10,\"comments\":2,\"blobs\":{}},\"name\":\"src/main.rs\"}],\"children\":{},\"inaccurate\":false},\"Total\":{\"blanks\":1,\"comments\":2,\"code\":10,\"reports\":[],\"children\":{},\"inaccurate\":false}}"
  let s = snapshot_from_json(text).unwrap()
  assert_eq(s.source, "tokeimbt")
  assert_eq(s.files.length(), 1)
  assert_eq(s.files[0].path, "src/main.rs")
  assert_eq(s.files[0].language, "Rust")
  assert_eq(s.files[0].code, 10)
  assert_eq(s.files[0].comment, 2)
  assert_eq(s.files[0].complexity, 0)
}

///|
test "baseline: malformed JSON returns None" {
  assert_true(snapshot_from_json("not json") is None)
}

///|
test "baseline: UTF-8 BOM prefix is tolerated" {
  let s = snap([file("a.mbt", 10, 2, 3)], "mooncloc")
  let text = snapshot_to_json(s)
  let with_bom = "\u{FEFF}" + text
  let back = snapshot_from_json(with_bom).unwrap()
  assert_eq(back.source, "mooncloc")
  assert_eq(back.files.length(), 1)
  assert_eq(back.files[0].code, 10)
}

///|
test "baseline: diff detects added, removed and changed files" {
  let base = snap(
    [file("a.mbt", 10, 5, 3), file("gone.mbt", 4, 1, 1)],
    "mooncloc",
  )
  let current = snap(
    [file("a.mbt", 14, 5, 6), file("new.mbt", 2, 2, 0)],
    "mooncloc",
  )
  let d = diff_snapshots(base, current)
  assert_eq(d.added, 1)
  assert_eq(d.removed, 1)
  assert_eq(d.changed, 1)
  assert_eq(d.code_delta, 2)
  assert_eq(d.complexity_delta, 2)
  assert_eq(d.current_code, 16)
  assert_eq(d.base_code, 14)
}

///|
test "baseline: diff of identical snapshots is clean" {
  let s = snap([file("a.mbt", 10, 5, 3)], "mooncloc")
  let d = diff_snapshots(s, s)
  assert_eq(d.added, 0)
  assert_eq(d.removed, 0)
  assert_eq(d.changed, 0)
  assert_eq(d.unchanged, 1)
  assert_eq(d.code_delta, 0)
}

///|
test "baseline: gate blocks code growth above limit" {
  let base = snap([file("a.mbt", 10, 5, 3)], "mooncloc")
  let current = snap([file("a.mbt", 20, 5, 3)], "mooncloc")
  let d = diff_snapshots(base, current)
  let policy = GatePolicy::default()
  let policy = policy.with_max_code_growth(5)
  let violations = evaluate_gate(policy, d, current)
  assert_eq(violations.length(), 1)
  assert_eq(violations[0].rule, "max_code_growth")
}

///|
test "baseline: gate passes when growth within limit" {
  let base = snap([file("a.mbt", 10, 5, 3)], "mooncloc")
  let current = snap([file("a.mbt", 12, 5, 3)], "mooncloc")
  let d = diff_snapshots(base, current)
  let policy = GatePolicy::default()
  let policy = policy.with_max_code_growth(5)
  let violations = evaluate_gate(policy, d, current)
  assert_eq(violations.length(), 0)
}

///|
test "baseline: gate blocks complexity growth" {
  let base = snap([file("a.mbt", 10, 5, 3)], "mooncloc")
  let current = snap([file("a.mbt", 10, 5, 9)], "mooncloc")
  let d = diff_snapshots(base, current)
  let policy = GatePolicy::default()
  let policy = policy.with_max_complexity_growth(2)
  let violations = evaluate_gate(policy, d, current)
  assert_eq(violations.length(), 1)
  assert_eq(violations[0].rule, "max_complexity_growth")
}

///|
test "baseline: gate blocks low comment ratio" {
  let current = snap([file("a.mbt", 100, 1, 3)], "mooncloc")
  let d = diff_snapshots(current, current)
  let policy = GatePolicy::default()
  let policy = policy.with_min_comment_ratio(10.0)
  let violations = evaluate_gate(policy, d, current)
  assert_eq(violations.length(), 1)
  assert_eq(violations[0].rule, "min_comment_ratio")
}

///|
test "baseline: gate blocks file over max complexity" {
  let current = snap([file("a.mbt", 10, 5, 42)], "mooncloc")
  let d = diff_snapshots(current, current)
  let policy = GatePolicy::default()
  let policy = policy.with_max_file_complexity(30)
  let violations = evaluate_gate(policy, d, current)
  assert_eq(violations.length(), 1)
  assert_eq(violations[0].rule, "max_file_complexity")
}

///|
test "baseline: complexity rules skipped for imported Tokei baseline" {
  let base = snap([file("a.mbt", 10, 5, 0)], "tokeimbt")
  let current = snap([file("a.mbt", 10, 5, 42)], "mooncloc")
  let d = diff_snapshots(base, current)
  assert_true(complexity_rules_skipped(d, current))
  let policy = GatePolicy::default()
  let policy = policy.with_max_file_complexity(30)
  let policy = policy.with_max_complexity_growth(1)
  let violations = evaluate_gate(policy, d, current)
  assert_eq(violations.length(), 0)
}

///|
test "baseline: diff table and JSON rendering" {
  let base = snap([file("a.mbt", 10, 5, 3)], "mooncloc")
  let current = snap([file("a.mbt", 12, 5, 4)], "mooncloc")
  let d = diff_snapshots(base, current)
  let table = render_diff_table(d)
  assert_true(table.contains("a.mbt"))
  assert_true(table.contains("changed"))
  let json = render_diff_json(d, [], false)
  assert_true(json.contains("\"gate_passed\": true"))
  assert_true(json.contains("\"code_delta\": 2"))
}

///|
test "baseline: relative baseline path matches absolute scan path" {
  let base = snap([file("src/main.mbt", 10, 5, 3)], "tokeimbt")
  let current = snap([file("C:/repo/src/main.mbt", 12, 5, 3)], "mooncloc")
  let d = diff_snapshots(base, current)
  assert_eq(d.added, 0)
  assert_eq(d.removed, 0)
  assert_eq(d.changed, 1)
  assert_eq(d.code_delta, 2)
}

///|
test "baseline: ambiguous suffix match is not guessed" {
  let base = snap([file("main.mbt", 10, 5, 3)], "tokeimbt")
  let current = snap(
    [file("a/main.mbt", 10, 5, 3), file("b/main.mbt", 10, 5, 3)],
    "mooncloc",
  )
  let d = diff_snapshots(base, current)
  assert_eq(d.removed, 1)
  assert_eq(d.added, 2)
}
