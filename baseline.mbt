///|
/// Temporal quality gate: snapshot, diff and regression gating.
///
/// This module is the layer that a plain line counter does not provide.
/// A counter (`tokei`, `TokeiMBT`, classic `cloc`) answers "how much code is
/// there?".  mooncloc additionally answers "did THIS change make the code
/// base worse, and should CI block it?".
///
/// It does so without re-implementing counting: a baseline can be produced by
/// mooncloc itself, or imported from a TokeiMBT / tokei JSON report via
/// `snapshot_from_json`.  That makes the tool an *extension* of the existing
/// counters rather than a competing re-implementation.

///|
/// One file's metrics at a point in time.
pub struct SnapshotFile {
  path : String
  language : String
  code : Int32
  comment : Int32
  blank : Int32
  /// 0 when the snapshot source does not measure complexity (TokeiMBT).
  complexity : Int32
}

///|
/// A point-in-time metric set. `source` records who produced it so that the
/// gate can be explicit about which rules are meaningful for that snapshot.
pub struct Snapshot {
  source : String
  files : Array[SnapshotFile]
}

///|
/// Per-file change between a baseline snapshot and a current scan.
pub struct FileDelta {
  path : String
  language : String
  status : String
  code_delta : Int32
  comment_delta : Int32
  blank_delta : Int32
  complexity_delta : Int32
}

///|
/// Aggregate result of comparing two snapshots.
pub struct DiffResult {
  deltas : Array[FileDelta]
  added : Int32
  removed : Int32
  changed : Int32
  unchanged : Int32
  code_delta : Int32
  comment_delta : Int32
  blank_delta : Int32
  complexity_delta : Int32
  base_code : Int32
  current_code : Int32
  base_comment : Int32
  current_comment : Int32
  base_complexity : Int32
  current_complexity : Int32
  source : String
  base_source : String
}

///|
/// Thresholds for a CI quality gate. `None` means the rule is disabled.
pub struct GatePolicy {
  max_code_growth : Int32?
  max_complexity_growth : Int32?
  min_comment_ratio : Double?
  max_file_complexity : Int32?
}

///|
/// A single violated gate rule.
pub struct GateViolation {
  rule : String
  detail : String
}

///|
/// Build a snapshot from a fresh mooncloc scan.
pub fn snapshot_from_counts(counts : Array[FileCount]) -> Snapshot {
  let files : Array[SnapshotFile] = []
  for f in counts {
    files.push({
      path: normalize_snapshot_path(f.path),
      language: f.language,
      code: f.code,
      comment: f.comment,
      blank: f.blank,
      complexity: f.complexity,
    })
  }
  { source: "mooncloc", files, }
}

///|
/// Normalize a path for cross-tool / cross-platform comparison.
fn normalize_snapshot_path(path : String) -> String {
  let mut p = path.replace_all(old="\\", new="/")
  while p.has_prefix("./") {
    p = p[2:].to_owned()
  }
  p
}

///|
/// Serialize a snapshot to the self-describing mooncloc baseline format.
/// The `tool` marker lets `snapshot_from_json` distinguish it from a
/// TokeiMBT / tokei report.
pub fn snapshot_to_json(snapshot : Snapshot) -> String {
  let root : Map[String, @json.Json] = Map([])
  root["tool"] = @json.Json::string("mooncloc")
  root["version"] = @json.Json::number(1.0)
  root["source"] = @json.Json::string(snapshot.source)
  let arr : Array[@json.Json] = []
  for f in snapshot.files {
    let m : Map[String, @json.Json] = Map([])
    m["path"] = @json.Json::string(f.path)
    m["language"] = @json.Json::string(f.language)
    m["code"] = @json.Json::number(f.code.to_double())
    m["comment"] = @json.Json::number(f.comment.to_double())
    m["blank"] = @json.Json::number(f.blank.to_double())
    m["complexity"] = @json.Json::number(f.complexity.to_double())
    arr.push(@json.Json::object(m))
  }
  root["files"] = @json.Json::array(arr)
  @json.Json::object(root).stringify(indent=2)
}

///|
/// JSON field access helpers shared by both snapshot readers.
fn jint(value : @json.Json, key : String) -> Int32? {
  match value {
    Object(fields) =>
      match fields.get(key) {
        Some(Number(n, ..)) if n >= 0.0 && n <= 2147483647.0 => Some(n.to_int())
        _ => None
      }
    _ => None
  }
}

///|
fn jstring(value : @json.Json, key : String) -> String? {
  match value {
    Object(fields) =>
      match fields.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
/// Read a JSON document, returning None for malformed input. A leading UTF-8
/// BOM (common in files written by Windows tools) is stripped first.
fn parse_doc(text : String) -> @json.Json? {
  let cleaned = if text.has_prefix("\u{FEFF}") {
    text[1:].to_owned()
  } else {
    text
  }
  Some(@json.parse(cleaned)) catch {
    _ => None
  }
}

///|
/// Load a baseline snapshot from JSON. Two formats are accepted:
///
/// 1. mooncloc's own baseline (`"tool": "mooncloc"`), produced by
///    `snapshot_to_json`;
/// 2. a TokeiMBT / tokei JSON report (language-keyed object with `reports`).
///
/// Accepting format 2 is the reuse bridge: teams already running TokeiMBT can
/// feed its report straight into mooncloc's gate without changing their
/// counting step.  Tokei reports carry no complexity data, so those metrics
/// are recorded as 0 and complexity-based gate rules are skipped explicitly.
pub fn snapshot_from_json(text : String) -> Snapshot? {
  let doc = match parse_doc(text) {
    Some(d) => d
    None => return None
  }
  let fields = match doc {
    Object(m) => m
    _ => return None
  }
  match fields.get("tool") {
    Some(String(tool)) if tool == "mooncloc" => parse_mooncloc(fields)
    _ => parse_tokei(doc)
  }
}

///|
fn parse_mooncloc(fields : Map[String, @json.Json]) -> Snapshot? {
  let entries = match fields.get("files") {
    Some(Array(a)) => a
    _ => return None
  }
  let source = match fields.get("source") {
    Some(String(s)) => s
    _ => "mooncloc"
  }
  let files : Array[SnapshotFile] = []
  for entry in entries {
    let path = jstring(entry, "path")
    let lang = jstring(entry, "language")
    let code = jint(entry, "code")
    let comment = jint(entry, "comment")
    let blank = jint(entry, "blank")
    match (path, lang, code, comment, blank) {
      (Some(path), Some(lang), Some(code), Some(comment), Some(blank)) =>
        files.push({
          path: normalize_snapshot_path(path),
          language: lang,
          code,
          comment,
          blank,
          complexity: jint(entry, "complexity").unwrap_or(0),
        })
      _ => return None
    }
  }
  Some({ source, files, })
}

///|
/// Parse a TokeiMBT / tokei JSON report into a snapshot.
/// Shape: { "Rust": { "reports": [ { "name": ..., "stats": {
/// "code": .., "comments": .., "blanks": .. } } ] }, "Total": { ... } }
fn parse_tokei(doc : @json.Json) -> Snapshot? {
  let items = match doc {
    Object(m) => m
    _ => return None
  }
  let files : Array[SnapshotFile] = []
  let mut found = false
  for item in items {
    if item.0 == "Total" {
      continue
    }
    let language = item.0
    let reports = match item.1 {
      Object(m) =>
        match m.get("reports") {
          Some(Array(a)) => a
          _ => continue
        }
      _ => continue
    }
    for report in reports {
      let path = jstring(report, "name")
      let stats = match report {
        Object(m) =>
          match m.get("stats") {
            Some(s) => s
            None => continue
          }
        _ => continue
      }
      let code = jint(stats, "code")
      let comment = jint(stats, "comments")
      let blank = jint(stats, "blanks")
      match (path, code, comment, blank) {
        (Some(path), Some(code), Some(comment), Some(blank)) => {
          files.push({
            path: normalize_snapshot_path(path),
            language,
            code,
            comment,
            blank,
            complexity: 0,
          })
          found = true
        }
        _ => ()
      }
    }
  }
  if found {
    Some({ source: "tokeimbt", files, })
  } else {
    None
  }
}

///|
/// Compare a baseline snapshot against the current snapshot, matching files
/// by normalized path. Complexity deltas are reported as 0 when either side
/// comes from a source without complexity data.
pub fn diff_snapshots(base : Snapshot, current : Snapshot) -> DiffResult {
  let base_map : Map[String, SnapshotFile] = Map([])
  let current_map : Map[String, SnapshotFile] = Map([])
  for f in base.files {
    base_map[f.path] = f
  }
  for f in current.files {
    current_map[f.path] = f
  }
  let current_paths : Array[String] = []
  for f in current.files {
    if !current_paths.contains(f.path) {
      current_paths.push(f.path)
    }
  }
  let deltas : Array[FileDelta] = []
  let mut added = 0
  let mut removed = 0
  let mut changed = 0
  let mut unchanged = 0
  let mut code_delta = 0
  let mut comment_delta = 0
  let mut blank_delta = 0
  let mut complexity_delta = 0
  let mut base_code = 0
  let mut current_code = 0
  let mut base_comment = 0
  let mut current_comment = 0
  let mut base_complexity = 0
  let mut current_complexity = 0
  for f in base.files {
    base_code = base_code + f.code
    base_comment = base_comment + f.comment
    base_complexity = base_complexity + f.complexity
  }
  for f in current.files {
    current_code = current_code + f.code
    current_comment = current_comment + f.comment
    current_complexity = current_complexity + f.complexity
  }
  // Iterate base files as the canonical set. Each current file is consumed at
  // most once, so a suffix match cannot double-count a file.
  let used_current : Array[String] = []
  for old in base.files {
    let matched = match_current_path(old.path, current_paths, used_current)
    match matched {
      None => {
        removed = removed + 1
        code_delta = code_delta - old.code
        comment_delta = comment_delta - old.comment
        blank_delta = blank_delta - old.blank
        complexity_delta = complexity_delta - old.complexity
        deltas.push({
          path: old.path,
          language: old.language,
          status: "removed",
          code_delta: -old.code,
          comment_delta: -old.comment,
          blank_delta: -old.blank,
          complexity_delta: -old.complexity,
        })
      }
      Some(key) => {
        used_current.push(key)
        let new = current_map.get(key).unwrap()
        let dc = new.code - old.code
        let dcm = new.comment - old.comment
        let db = new.blank - old.blank
        let dx = new.complexity - old.complexity
        code_delta = code_delta + dc
        comment_delta = comment_delta + dcm
        blank_delta = blank_delta + db
        complexity_delta = complexity_delta + dx
        let status = if dc == 0 && dcm == 0 && db == 0 && dx == 0 {
          unchanged = unchanged + 1
          "unchanged"
        } else {
          changed = changed + 1
          "changed"
        }
        deltas.push({
          path: new.path,
          language: new.language,
          status,
          code_delta: dc,
          comment_delta: dcm,
          blank_delta: db,
          complexity_delta: dx,
        })
      }
    }
  }
  // Whatever was not consumed is a newly added file.
  for f in current.files {
    if !used_current.contains(f.path) {
      added = added + 1
      code_delta = code_delta + f.code
      comment_delta = comment_delta + f.comment
      blank_delta = blank_delta + f.blank
      complexity_delta = complexity_delta + f.complexity
      deltas.push({
        path: f.path,
        language: f.language,
        status: "added",
        code_delta: f.code,
        comment_delta: f.comment,
        blank_delta: f.blank,
        complexity_delta: f.complexity,
      })
    }
  }
  deltas.sort_by(fn(a, b) { a.path.compare(b.path) })
  {
    deltas,
    added,
    removed,
    changed,
    unchanged,
    code_delta,
    comment_delta,
    blank_delta,
    complexity_delta,
    base_code,
    current_code,
    base_comment,
    current_comment,
    base_complexity,
    current_complexity,
    source: current.source,
    base_source: base.source,
  }
}

///|
/// Match a baseline path to a current-scan path. Exact match wins; otherwise
/// a unique segment-boundary suffix match is used. This lets a TokeiMBT
/// baseline with relative paths (`src/main.rs`) be compared against a scan
/// that used absolute paths, without confusing two files that share a name.
fn match_current_path(
  path : String,
  candidates : Array[String],
  used : Array[String],
) -> String? {
  let available : Array[String] = []
  for c in candidates {
    if !used.contains(c) {
      available.push(c)
    }
  }
  if available.contains(path) {
    return Some(path)
  }
  let needle = "/" + path
  let mut hit : String? = None
  let mut count = 0
  for c in available {
    if c.has_suffix(needle) {
      hit = Some(c)
      count = count + 1
    }
  }
  if count == 1 {
    hit
  } else {
    None
  }
}

///|
/// Comment ratio of a snapshot: comments over (code + comments), as a
/// percentage in [0, 100].
pub fn comment_ratio_pct(snapshot : Snapshot) -> Double {
  let mut code = 0
  let mut comment = 0
  for f in snapshot.files {
    code = code + f.code
    comment = comment + f.comment
  }
  let total = code + comment
  if total == 0 {
    0.0
  } else {
    comment.to_double() * 100.0 / total.to_double()
  }
}

///|
/// A permissive default policy: no rule is enforced until it is configured.
pub fn GatePolicy::default() -> GatePolicy {
  {
    max_code_growth: None,
    max_complexity_growth: None,
    min_comment_ratio: None,
    max_file_complexity: None,
  }
}

///|
pub fn GatePolicy::with_max_code_growth(
  self : GatePolicy,
  n : Int32,
) -> GatePolicy {
  {
    max_code_growth: Some(n),
    max_complexity_growth: self.max_complexity_growth,
    min_comment_ratio: self.min_comment_ratio,
    max_file_complexity: self.max_file_complexity,
  }
}

///|
pub fn GatePolicy::with_max_complexity_growth(
  self : GatePolicy,
  n : Int32,
) -> GatePolicy {
  {
    max_code_growth: self.max_code_growth,
    max_complexity_growth: Some(n),
    min_comment_ratio: self.min_comment_ratio,
    max_file_complexity: self.max_file_complexity,
  }
}

///|
pub fn GatePolicy::with_min_comment_ratio(
  self : GatePolicy,
  n : Double,
) -> GatePolicy {
  {
    max_code_growth: self.max_code_growth,
    max_complexity_growth: self.max_complexity_growth,
    min_comment_ratio: Some(n),
    max_file_complexity: self.max_file_complexity,
  }
}

///|
pub fn GatePolicy::with_max_file_complexity(
  self : GatePolicy,
  n : Int32,
) -> GatePolicy {
  {
    max_code_growth: self.max_code_growth,
    max_complexity_growth: self.max_complexity_growth,
    min_comment_ratio: self.min_comment_ratio,
    max_file_complexity: Some(n),
  }
}

///|
/// Evaluate a diff against a policy. Returns the list of violated rules; an
/// empty list means the gate passes.
///
/// Rules that need complexity data are skipped when the baseline came from a
/// counter that does not measure it, and a `skipped` note is emitted by the
/// renderer so the result is never silently misread.
pub fn evaluate_gate(
  policy : GatePolicy,
  diff : DiffResult,
  current : Snapshot,
) -> Array[GateViolation] {
  let violations : Array[GateViolation] = []
  match policy.max_code_growth {
    Some(limit) =>
      if diff.code_delta > limit {
        violations.push({
          rule: "max_code_growth",
          detail: "code grew by " +
          signed(diff.code_delta) +
          " lines (limit +" +
          limit.to_string() +
          ")",
        })
      }
    None => ()
  }
  let complexity_known = current.source == "mooncloc" &&
    diff.base_source == "mooncloc"
  match policy.max_complexity_growth {
    Some(limit) =>
      if complexity_known {
        if diff.complexity_delta > limit {
          violations.push({
            rule: "max_complexity_growth",
            detail: "complexity grew by " +
            signed(diff.complexity_delta) +
            " (limit +" +
            limit.to_string() +
            ")",
          })
        }
      }
    None => ()
  }
  match policy.min_comment_ratio {
    Some(min) => {
      let ratio = comment_ratio_pct(current)
      if ratio < min {
        violations.push({
          rule: "min_comment_ratio",
          detail: "comment ratio " +
          percent(ratio) +
          " is below " +
          percent(min),
        })
      }
    }
    None => ()
  }
  match policy.max_file_complexity {
    Some(limit) =>
      if complexity_known {
        for f in current.files {
          if f.complexity > limit {
            violations.push({
              rule: "max_file_complexity",
              detail: f.path +
              " has complexity " +
              f.complexity.to_string() +
              " (limit " +
              limit.to_string() +
              ")",
            })
          }
        }
      }
    None => ()
  }
  violations
}

///|
/// Whether a gate rule that needs complexity was skipped.
pub fn complexity_rules_skipped(diff : DiffResult, current : Snapshot) -> Bool {
  current.source != "mooncloc" || diff.base_source != "mooncloc"
}

///|
fn signed(n : Int32) -> String {
  if n >= 0 {
    "+" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn percent(v : Double) -> String {
  let tenths = (v * 10.0).round().to_int()
  (tenths / 10).to_string() + "." + (tenths % 10).to_string() + "%"
}

///|
/// Render a diff result as an aligned table.
pub fn render_diff_table(diff : DiffResult) -> String {
  let header = ["File", "Language", "Status", "Code", "Comment", "Blank", "Cx"]
  let rows : Array[Array[String]] = []
  for d in diff.deltas {
    if d.status != "unchanged" {
      rows.push([
        d.path,
        d.language,
        d.status,
        signed(d.code_delta),
        signed(d.comment_delta),
        signed(d.blank_delta),
        signed(d.complexity_delta),
      ])
    }
  }
  let sb = StringBuilder()
  sb.write_string(render_table_local(header, rows))
  sb.write_string("\n")
  sb.write_string(
    "files: +" +
    diff.added.to_string() +
    " added, -" +
    diff.removed.to_string() +
    " removed, ~" +
    diff.changed.to_string() +
    " changed, " +
    diff.unchanged.to_string() +
    " unchanged\n",
  )
  sb.write_string(
    "totals: code " +
    signed(diff.code_delta) +
    " (" +
    diff.base_code.to_string() +
    " -> " +
    diff.current_code.to_string() +
    ")" +
    ", comment " +
    signed(diff.comment_delta) +
    ", blank " +
    signed(diff.blank_delta) +
    ", complexity " +
    signed(diff.complexity_delta) +
    "\n",
  )
  sb.to_string()
}

///|
/// Render gate verdict text.
pub fn render_gate(violations : Array[GateViolation], skipped : Bool) -> String {
  let sb = StringBuilder()
  if violations.length() == 0 {
    sb.write_string("quality gate: PASS\n")
  } else {
    sb.write_string(
      "quality gate: FAIL (" +
      violations.length().to_string() +
      " violation(s))\n",
    )
    for v in violations {
      sb.write_string("  [" + v.rule + "] " + v.detail + "\n")
    }
  }
  if skipped {
    sb.write_string(
      "  note: baseline source has no complexity data; complexity rules skipped\n",
    )
  }
  sb.to_string()
}

///|
/// Render the whole comparison as JSON (machine readable for CI dashboards).
pub fn render_diff_json(
  diff : DiffResult,
  violations : Array[GateViolation],
  skipped : Bool,
) -> String {
  let root : Map[String, @json.Json] = Map([])
  root["source"] = @json.Json::string(diff.source)
  root["code_delta"] = @json.Json::number(diff.code_delta.to_double())
  root["comment_delta"] = @json.Json::number(diff.comment_delta.to_double())
  root["blank_delta"] = @json.Json::number(diff.blank_delta.to_double())
  root["complexity_delta"] = @json.Json::number(
    diff.complexity_delta.to_double(),
  )
  root["base_code"] = @json.Json::number(diff.base_code.to_double())
  root["current_code"] = @json.Json::number(diff.current_code.to_double())
  root["added"] = @json.Json::number(diff.added.to_double())
  root["removed"] = @json.Json::number(diff.removed.to_double())
  root["changed"] = @json.Json::number(diff.changed.to_double())
  root["unchanged"] = @json.Json::number(diff.unchanged.to_double())
  root["gate_passed"] = @json.Json::boolean(violations.length() == 0)
  root["complexity_rules_skipped"] = @json.Json::boolean(skipped)
  let arr : Array[@json.Json] = []
  for d in diff.deltas {
    if d.status != "unchanged" {
      let m : Map[String, @json.Json] = Map([])
      m["path"] = @json.Json::string(d.path)
      m["language"] = @json.Json::string(d.language)
      m["status"] = @json.Json::string(d.status)
      m["code_delta"] = @json.Json::number(d.code_delta.to_double())
      m["comment_delta"] = @json.Json::number(d.comment_delta.to_double())
      m["blank_delta"] = @json.Json::number(d.blank_delta.to_double())
      m["complexity_delta"] = @json.Json::number(d.complexity_delta.to_double())
      arr.push(@json.Json::object(m))
    }
  }
  root["changes"] = @json.Json::array(arr)
  let varr : Array[@json.Json] = []
  for v in violations {
    let m : Map[String, @json.Json] = Map([])
    m["rule"] = @json.Json::string(v.rule)
    m["detail"] = @json.Json::string(v.detail)
    varr.push(@json.Json::object(m))
  }
  root["violations"] = @json.Json::array(varr)
  @json.Json::object(root).stringify(indent=2)
}

///|
/// Minimal aligned table renderer (kept local so this module stays reusable
/// as a library without depending on report formatting details).
fn render_table_local(
  header : Array[String],
  rows : Array[Array[String]],
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
  let sb = StringBuilder()
  sb.write_string(pad_row_local(header, widths))
  sb.write_string("\n")
  let seps : Array[String] = []
  for w in widths {
    seps.push("-".repeat(w))
  }
  sb.write_string(seps.join("  "))
  sb.write_string("\n")
  for row in rows {
    sb.write_string(pad_row_local(row, widths))
    sb.write_string("\n")
  }
  sb.to_string()
}

///|
fn pad_row_local(cells : Array[String], widths : Array[Int32]) -> String {
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
