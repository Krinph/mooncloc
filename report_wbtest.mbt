///|
/// White-box unit tests for report aggregation and rendering.

///|
fn sample_counts() -> Array[FileCount] {
  [
    {
      path: "a.mbt",
      language: "MoonBit",
      blank: 1,
      comment: 2,
      code: 3,
      mixed: 0,
      complexity: 4,
    },
    {
      path: "b.mbt",
      language: "MoonBit",
      blank: 1,
      comment: 2,
      code: 3,
      mixed: 0,
      complexity: 4,
    },
    {
      path: "c.py",
      language: "Python",
      blank: 1,
      comment: 2,
      code: 5,
      mixed: 0,
      complexity: 2,
    },
  ]
}

///|
test "report: totals aggregation" {
  let totals = report_totals(sample_counts())
  assert_eq(totals.files, 3)
  assert_eq(totals.blank, 3)
  assert_eq(totals.comment, 6)
  assert_eq(totals.code, 11)
  assert_eq(totals.complexity, 10)
}

///|
test "report: aggregate by language, sorted by code desc" {
  let groups = aggregate_by_language(sample_counts())
  assert_eq(groups.length(), 2)
  assert_eq(groups[0].0, "MoonBit")
  assert_eq(groups[0].1.files, 2)
  assert_eq(groups[0].1.code, 6)
  assert_eq(groups[1].0, "Python")
  assert_eq(groups[1].1.code, 5)
}

///|
test "report: table format contains totals" {
  let text = render_report(sample_counts(), ReportFormat::Table, false)
  assert_true(text.contains("Language"))
  assert_true(text.contains("Total"))
  assert_true(text.contains("11"))
  assert_true(text.contains("MoonBit"))
}

///|
test "report: markdown format renders a table" {
  let text = render_report(sample_counts(), ReportFormat::Markdown, false)
  assert_true(text.contains("| Language |"))
  assert_true(text.contains("**Total**"))
  assert_true(text.contains("Python"))
}

///|
test "report: csv format has header and total row" {
  let text = render_report(sample_counts(), ReportFormat::Csv, false)
  assert_true(text.contains("language,files,blank,comment,code"))
  assert_true(text.contains("Total"))
}

///|
test "report: csv escapes commas and quotes" {
  let text = csv_escape("a,b")
  assert_eq(text, "\"a,b\"")
  let text2 = csv_escape("say \"hi\"")
  assert_eq(text2, "\"say \"\"hi\"\"\"")
  let text3 = csv_escape("plain")
  assert_eq(text3, "plain")
}

///|
test "report: json output is parseable and correct" {
  let text = render_report(sample_counts(), ReportFormat::Json, false)
  let json = @json.parse(text)
  match json {
    @json.Json::Object(map) =>
      match map["totals"] {
        @json.Json::Object(_) => ()
        _ => fail("expected totals to be an object")
      }
    _ => fail("expected an object")
  }
  assert_true(text.contains("\"totals\""))
  assert_true(text.contains("\"by_language\""))
}

///|
test "report: per-file json includes file paths" {
  let text = render_report(sample_counts(), ReportFormat::Json, true)
  assert_true(text.contains("\"files\""))
  assert_true(text.contains("a.mbt"))
  assert_true(text.contains("c.py"))
}

///|
test "report: format_by_name parsing" {
  assert_true(format_by_name("json") is ReportFormat::Json)
  assert_true(format_by_name("csv") is ReportFormat::Csv)
  assert_true(format_by_name("markdown") is ReportFormat::Markdown)
  assert_true(format_by_name("table") is ReportFormat::Table)
  assert_true(format_by_name("bogus") is ReportFormat::Table)
}

///|
test "report: most complex files are sorted descending" {
  let counts = sample_counts()
  let top = most_complex_files(counts, 2)
  assert_eq(top.length(), 2)
  assert_eq(top[0].path, "a.mbt")
  assert_eq(top[0].complexity, 4)
  assert_eq(top[1].complexity, 4)
  let all = most_complex_files(counts, 10)
  assert_eq(all.length(), 3)
}

///|
test "report: comment ratio and complexity density" {
  let counts = sample_counts()
  // comment 6, code 11 -> ratio 6/17
  let ratio = comment_ratio(counts)
  assert_eq(ratio, 6.0 / 17.0)
  // complexity 10 / code 11
  let density = complexity_per_code(counts)
  assert_eq(density, 10.0 / 11.0)
  assert_eq(comment_ratio([]), 0.0)
  assert_eq(complexity_per_code([]), 0.0)
}

///|
test "report: per-file table includes file rows and health line" {
  let text = render_report(sample_counts(), ReportFormat::Table, true)
  assert_true(text.contains("a.mbt"))
  assert_true(text.contains("c.py"))
  assert_true(text.contains("comment ratio"))
  assert_true(text.contains("most complex file"))
}

///|
test "report: json health section" {
  let text = render_report(sample_counts(), ReportFormat::Json, false)
  assert_true(text.contains("\"health\""))
  assert_true(text.contains("\"comment_ratio\""))
  assert_true(text.contains("\"most_complex_file\""))
}
