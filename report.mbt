///|
/// Report rendering: turn per-file counts into a human-readable table, JSON,
/// CSV or Markdown document.

///|
pub enum ReportFormat {
  Table
  Json
  Csv
  Markdown
}

///|
/// Parse an output format name (`table`, `json`, `csv`, `markdown`);
/// anything else falls back to the default table format.
pub fn format_by_name(name : String) -> ReportFormat {
  match name {
    "json" => ReportFormat::Json
    "csv" => ReportFormat::Csv
    "markdown" => ReportFormat::Markdown
    _ => ReportFormat::Table
  }
}

///|
/// Render a report for the given counts.
/// `per_file` includes a per-file breakdown (all formats).
pub fn render_report(
  counts : Array[FileCount],
  format : ReportFormat,
  per_file : Bool,
) -> String {
  let totals = report_totals(counts)
  let groups = aggregate_by_language(counts)
  match format {
    ReportFormat::Table =>
      if per_file {
        render_table_with_detail(counts, groups, totals)
      } else {
        render_table(groups, totals)
      }
    ReportFormat::Json => render_json(counts, groups, totals, per_file)
    ReportFormat::Csv => render_csv(counts, groups, totals, per_file)
    ReportFormat::Markdown => render_markdown(groups, totals)
  }
}

///|
/// The `n` most complex files, sorted by cyclomatic complexity descending
/// (ties broken by code lines descending).
pub fn most_complex_files(
  counts : Array[FileCount],
  limit : Int32,
) -> Array[FileCount] {
  let sorted = sort_files_by_complexity(counts)
  if limit >= sorted.length() {
    sorted
  } else {
    sorted[0:limit].to_owned()
  }
}

///|
fn sort_files_by_complexity(files : Array[FileCount]) -> Array[FileCount] {
  let sorted : Array[FileCount] = []
  for f in files {
    sorted.push(f)
  }
  for i = 0; i < sorted.length(); i = i + 1 {
    for j = i + 1; j < sorted.length(); j = j + 1 {
      let needs_swap = sorted[j].complexity > sorted[i].complexity ||
        (
          sorted[j].complexity == sorted[i].complexity &&
          sorted[j].code > sorted[i].code
        )
      if needs_swap {
        let tmp = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = tmp
      }
    }
  }
  sorted
}

///|
/// Comment ratio: comment lines over (code + comment) lines, as a fraction in
/// [0, 1]. Returns 0.0 for empty input.
pub fn comment_ratio(counts : Array[FileCount]) -> Double {
  let totals = report_totals(counts)
  let total = totals.code + totals.comment
  if total == 0 {
    0.0
  } else {
    totals.comment.to_double() / total.to_double()
  }
}

///|
/// Average cyclomatic complexity per code line.
pub fn complexity_per_code(counts : Array[FileCount]) -> Double {
  let totals = report_totals(counts)
  if totals.code == 0 {
    0.0
  } else {
    totals.complexity.to_double() / totals.code.to_double()
  }
}

///|
/// Render a table with a per-file breakdown followed by the language summary
/// and a health line.
fn render_table_with_detail(
  counts : Array[FileCount],
  groups : Array[(String, ProjectCount)],
  totals : ProjectCount,
) -> String {
  let header = ["File", "Language", "Blank", "Comment", "Code", "Complexity"]
  let rows : Array[Array[String]] = []
  for f in counts {
    rows.push([
      f.path,
      f.language,
      f.blank.to_string(),
      f.comment.to_string(),
      f.code.to_string(),
      f.complexity.to_string(),
    ])
  }
  let sb = StringBuilder()
  sb.write_string(render_ascii_table(header, rows, []))
  sb.write_string("\n")
  sb.write_string(render_table(groups, totals))
  sb.write_string("\n")
  sb.write_string(health_line(counts))
  sb.write_string("\n")
  sb.to_string()
}

///|
/// A one-line health summary appended to table output.
fn health_line(counts : Array[FileCount]) -> String {
  let ratio = (comment_ratio(counts) * 100.0).round()
  let density = (complexity_per_code(counts) * 100.0).round()
  let top = most_complex_files(counts, 1)
  let top_name = if top.length() > 0 { top[0].path } else { "-" }
  "comment ratio: " +
  ratio.to_string() +
  "%   complexity per 100 code lines: " +
  density.to_string() +
  "   most complex file: " +
  top_name
}

///|
/// Render a monospace, column-aligned table.
fn render_table(
  groups : Array[(String, ProjectCount)],
  totals : ProjectCount,
) -> String {
  let header = ["Language", "Files", "Blank", "Comment", "Code", "Complexity"]
  let rows : Array[Array[String]] = []
  for (name, pc) in groups {
    rows.push([
      name,
      pc.files.to_string(),
      pc.blank.to_string(),
      pc.comment.to_string(),
      pc.code.to_string(),
      pc.complexity.to_string(),
    ])
  }
  let total_row = [
    "Total",
    totals.files.to_string(),
    totals.blank.to_string(),
    totals.comment.to_string(),
    totals.code.to_string(),
    totals.complexity.to_string(),
  ]
  render_ascii_table(header, rows, total_row)
}

///|
/// Render an aligned ASCII table with a header, data rows and a total row.
fn render_ascii_table(
  header : Array[String],
  rows : Array[Array[String]],
  total_row : Array[String],
) -> String {
  let widths : Array[Int32] = []
  for i = 0; i < header.length(); i = i + 1 {
    widths.push(header[i].length())
  }
  for row in rows {
    for i = 0; i < row.length(); i = i + 1 {
      if row[i].length() > widths[i] {
        widths[i] = row[i].length()
      }
    }
  }
  for i = 0; i < total_row.length(); i = i + 1 {
    if total_row[i].length() > widths[i] {
      widths[i] = total_row[i].length()
    }
  }
  let sb = StringBuilder()
  sb.write_string(pad_row(header, widths))
  sb.write_string("\n")
  sb.write_string(separator(widths))
  sb.write_string("\n")
  for row in rows {
    sb.write_string(pad_row(row, widths))
    sb.write_string("\n")
  }
  sb.write_string(separator(widths))
  sb.write_string("\n")
  sb.write_string(pad_row(total_row, widths))
  sb.write_string("\n")
  sb.to_string()
}

///|
fn pad_row(cells : Array[String], widths : Array[Int32]) -> String {
  let parts : Array[String] = []
  for i = 0; i < cells.length(); i = i + 1 {
    let w = widths[i]
    if i == 0 {
      parts.push(cells[i].pad_end(w, ' '))
    } else {
      parts.push(cells[i].pad_start(w, ' '))
    }
  }
  parts.join("  ")
}

///|
fn separator(widths : Array[Int32]) -> String {
  let parts : Array[String] = []
  for w in widths {
    parts.push("-".repeat(w))
  }
  parts.join("  ")
}

///|
/// Render a JSON document with totals, per-language breakdown and (optionally)
/// per-file detail.
fn render_json(
  counts : Array[FileCount],
  groups : Array[(String, ProjectCount)],
  totals : ProjectCount,
  per_file : Bool,
) -> String {
  let root : Map[String, @json.Json] = Map([])
  root["totals"] = project_count_json(totals)
  root["by_language"] = @json.Json::array(language_groups_json(groups))
  root["health"] = health_json(counts)
  if per_file {
    root["files"] = @json.Json::array(file_counts_json(counts))
  }
  @json.Json::object(root).stringify(indent=2)
}

///|
fn health_json(counts : Array[FileCount]) -> @json.Json {
  let m : Map[String, @json.Json] = Map([])
  m["comment_ratio"] = @json.Json::number(comment_ratio(counts))
  m["complexity_per_code"] = @json.Json::number(complexity_per_code(counts))
  let top = most_complex_files(counts, 1)
  let top_name = if top.length() > 0 { top[0].path } else { "" }
  m["most_complex_file"] = @json.Json::string(top_name)
  @json.Json::object(m)
}

///|
fn language_groups_json(
  groups : Array[(String, ProjectCount)],
) -> Array[@json.Json] {
  let arr : Array[@json.Json] = []
  for (name, pc) in groups {
    let m : Map[String, @json.Json] = Map([])
    m["language"] = @json.Json::string(name)
    m["files"] = @json.Json::Json(pc.files)
    m["blank"] = @json.Json::Json(pc.blank)
    m["comment"] = @json.Json::Json(pc.comment)
    m["code"] = @json.Json::Json(pc.code)
    m["mixed"] = @json.Json::Json(pc.mixed)
    m["complexity"] = @json.Json::Json(pc.complexity)
    arr.push(@json.Json::object(m))
  }
  arr
}

///|
fn file_counts_json(counts : Array[FileCount]) -> Array[@json.Json] {
  let arr : Array[@json.Json] = []
  for f in counts {
    let m : Map[String, @json.Json] = Map([])
    m["path"] = @json.Json::string(f.path)
    m["language"] = @json.Json::string(f.language)
    m["blank"] = @json.Json::Json(f.blank)
    m["comment"] = @json.Json::Json(f.comment)
    m["code"] = @json.Json::Json(f.code)
    m["mixed"] = @json.Json::Json(f.mixed)
    m["complexity"] = @json.Json::Json(f.complexity)
    arr.push(@json.Json::object(m))
  }
  arr
}

///|
fn project_count_json(pc : ProjectCount) -> @json.Json {
  let m : Map[String, @json.Json] = Map([])
  m["files"] = @json.Json::Json(pc.files)
  m["blank"] = @json.Json::Json(pc.blank)
  m["comment"] = @json.Json::Json(pc.comment)
  m["code"] = @json.Json::Json(pc.code)
  m["mixed"] = @json.Json::Json(pc.mixed)
  m["complexity"] = @json.Json::Json(pc.complexity)
  @json.Json::object(m)
}

///|
/// Render CSV with a header row, one row per language, and a total row.
/// When `per_file` is true, one row per file is emitted instead (with path
/// and language columns).
fn render_csv(
  counts : Array[FileCount],
  groups : Array[(String, ProjectCount)],
  totals : ProjectCount,
  per_file : Bool,
) -> String {
  let sb = StringBuilder()
  if per_file {
    sb.write_string(
      "path,language,blank,comment,code,mixed,complexity\n".to_string(),
    )
    for f in counts {
      sb.write_string(
        csv_join([
          csv_escape(f.path),
          csv_escape(f.language),
          f.blank.to_string(),
          f.comment.to_string(),
          f.code.to_string(),
          f.mixed.to_string(),
          f.complexity.to_string(),
        ]) +
        "\n",
      )
    }
  } else {
    sb.write_string(
      "language,files,blank,comment,code,mixed,complexity\n".to_string(),
    )
    for (name, pc) in groups {
      sb.write_string(
        csv_join([
          csv_escape(name),
          pc.files.to_string(),
          pc.blank.to_string(),
          pc.comment.to_string(),
          pc.code.to_string(),
          pc.mixed.to_string(),
          pc.complexity.to_string(),
        ]) +
        "\n",
      )
    }
    sb.write_string(
      csv_join([
        "Total",
        totals.files.to_string(),
        totals.blank.to_string(),
        totals.comment.to_string(),
        totals.code.to_string(),
        totals.mixed.to_string(),
        totals.complexity.to_string(),
      ]) +
      "\n",
    )
  }
  sb.to_string()
}

///|
fn csv_join(fields : Array[String]) -> String {
  fields.join(",")
}

///|
/// Quote a CSV field if it contains a comma, quote or newline.
fn csv_escape(field : String) -> String {
  if field.contains(",") || field.contains("\"") || field.contains("\n") {
    "\"" + field.replace_all(old="\"", new="\"\"") + "\""
  } else {
    field
  }
}

///|
/// Render a GitHub-flavored Markdown table.
fn render_markdown(
  groups : Array[(String, ProjectCount)],
  totals : ProjectCount,
) -> String {
  let sb = StringBuilder()
  sb.write_string(
    "| Language | Files | Blank | Comment | Code | Complexity |\n",
  )
  sb.write_string("| --- | --- | --- | --- | --- | --- |\n")
  for (name, pc) in groups {
    sb.write_string(
      "| " +
      name +
      " | " +
      pc.files.to_string() +
      " | " +
      pc.blank.to_string() +
      " | " +
      pc.comment.to_string() +
      " | " +
      pc.code.to_string() +
      " | " +
      pc.complexity.to_string() +
      " |\n",
    )
  }
  sb.write_string(
    "| **Total** | **" +
    totals.files.to_string() +
    "** | **" +
    totals.blank.to_string() +
    "** | **" +
    totals.comment.to_string() +
    "** | **" +
    totals.code.to_string() +
    "** | **" +
    totals.complexity.to_string() +
    "** |\n",
  )
  sb.to_string()
}
