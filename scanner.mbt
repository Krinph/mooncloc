///|
/// Directory scanning: walk a tree, count every recognized source file and
/// aggregate the results.

///|
/// Directories that are almost always noise and excluded by default.
pub let default_excludes : Array[String] = [
  ".git/", ".hg/", ".svn/", "target/", "_build/", "node_modules/", ".mooncakes/",
  ".moon/", ".venv/", "dist/", "build/", "vendor/", ".idea/", ".vscode/",
]

///|
/// Files larger than this are skipped (they are almost certainly binary or
/// generated artifacts).
pub let max_file_bytes : Int64 = 10 * 1024 * 1024

///|
/// Options controlling a directory scan.
pub struct CountOptions {
  include_hidden : Bool
  exclude : Array[String]
  languages : Array[String]
  count_mixed_as_code : Bool
  count_complexity : Bool
}

///|
pub fn CountOptions::default() -> CountOptions {
  {
    include_hidden: false,
    exclude: [],
    languages: [],
    count_mixed_as_code: true,
    count_complexity: true,
  }
}

///|
pub fn CountOptions::with_hidden(
  self : CountOptions,
  hidden : Bool,
) -> CountOptions {
  {
    include_hidden: hidden,
    exclude: self.exclude,
    languages: self.languages,
    count_mixed_as_code: self.count_mixed_as_code,
    count_complexity: self.count_complexity,
  }
}

///|
pub fn CountOptions::with_exclude(
  self : CountOptions,
  exclude : Array[String],
) -> CountOptions {
  {
    include_hidden: self.include_hidden,
    exclude,
    languages: self.languages,
    count_mixed_as_code: self.count_mixed_as_code,
    count_complexity: self.count_complexity,
  }
}

///|
pub fn CountOptions::with_languages(
  self : CountOptions,
  languages : Array[String],
) -> CountOptions {
  {
    include_hidden: self.include_hidden,
    exclude: self.exclude,
    languages,
    count_mixed_as_code: self.count_mixed_as_code,
    count_complexity: self.count_complexity,
  }
}

///|
pub fn CountOptions::with_complexity(
  self : CountOptions,
  enabled : Bool,
) -> CountOptions {
  {
    include_hidden: self.include_hidden,
    exclude: self.exclude,
    languages: self.languages,
    count_mixed_as_code: self.count_mixed_as_code,
    count_complexity: enabled,
  }
}

///|
/// Per-file count results.
pub struct FileCount {
  path : String
  language : String
  blank : Int32
  comment : Int32
  code : Int32
  mixed : Int32
  complexity : Int32
}

///|
/// Aggregated count results (a project or a single language).
pub struct ProjectCount {
  mut files : Int32
  mut blank : Int32
  mut comment : Int32
  mut code : Int32
  mut mixed : Int32
  mut complexity : Int32
}

///|
pub fn ProjectCount::default() -> ProjectCount {
  { files: 0, blank: 0, comment: 0, code: 0, mixed: 0, complexity: 0, }
}

///|
/// Count one in-memory file (used by the CLI for `--stdin` style input and by
/// tests).
pub fn count_file_text(
  text : String,
  lang : LanguageDef,
  options : CountOptions,
) -> FileCount {
  let c = count_text(text, lang, options.count_mixed_as_code)
  let cx = if options.count_complexity {
    count_complexity(text, lang)
  } else {
    0
  }
  {
    path: "",
    language: lang.name,
    blank: c.blank,
    comment: c.comment,
    code: c.code,
    mixed: c.mixed,
    complexity: cx,
  }
}

///|
/// Recursively scan `root` and return per-file counts plus a list of errors
/// encountered while reading files.
pub async fn scan_directory(
  root : String,
  options : CountOptions,
) -> (Array[FileCount], Array[String]) {
  let counts : Array[FileCount] = []
  let errors : Array[String] = []
  let excludes : Array[String] = []
  for e in default_excludes {
    excludes.push(e)
  }
  for e in options.exclude {
    excludes.push(e)
  }
  let rules = IgnoreRules::new(excludes)
  @fs.walk(
    root,
    max_concurrency=8,
    allow_failure=true,
    exclude=dir => rules.ignores(strip_root(root, dir)),
    (dir, entries) => {
      for name in entries {
        let full = dir + "/" + name
        let kind = @fs.kind(full) catch { _ => @fs.FileKind::Unknown }
        match kind {
          @fs.FileKind::Regular => {
            if !options.include_hidden && name.has_prefix(".") {
              continue
            }
            match detect_language(name) {
              Some(lang) => {
                if !language_wanted(lang.name, options.languages) {
                  continue
                }
                let size = @fs.file_size(full) catch { _ => 0L }
                if size > max_file_bytes {
                  continue
                }
                // Read the file; failures are recorded and the file skipped.
                match read_file_safe(full) {
                  Some(text) => {
                    let c = count_text(text, lang, options.count_mixed_as_code)
                    let cx = if options.count_complexity {
                      count_complexity(text, lang)
                    } else {
                      0
                    }
                    counts.push({
                      path: full,
                      language: lang.name,
                      blank: c.blank,
                      comment: c.comment,
                      code: c.code,
                      mixed: c.mixed,
                      complexity: cx,
                    })
                  }
                  None => errors.push("cannot read file: " + full)
                }
              }
              None => ()
            }
          }
          _ => ()
        }
      }
    },
  )
  (counts, errors)
}

///|
/// Read a text file, returning None on failure instead of aborting.
async fn read_file_safe(path : String) -> String? {
  match @fs.read_text(path) {
    text => Some(text)
  }
}

///|
/// Strip the scan root prefix from a path so ignore rules can be applied to
/// the relative path.
fn strip_root(root : String, path : String) -> String {
  let prefix = root + "/"
  match path.strip_prefix(prefix) {
    Some(rest) => rest.to_owned()
    None => path
  }
}

///|
/// Recognize the language of a file by its exact name or extension.
fn detect_language(name : String) -> LanguageDef? {
  match language_by_filename(name) {
    Some(lang) => return Some(lang)
    None => ()
  }
  match extension_of(name) {
    Some(ext) => language_by_extension(ext)
    None => None
  }
}

///|
fn extension_of(name : String) -> String? {
  match name.rev_find(".") {
    Some(pos) => Some(name[pos + 1:].to_owned())
    None => None
  }
}

///|
/// Is `name` in the requested language filter (empty filter = all)?
fn language_wanted(name : String, wanted : Array[String]) -> Bool {
  if wanted.length() == 0 {
    return true
  }
  for w in wanted {
    if w == name {
      return true
    }
  }
  false
}

///|
/// Total counts across all files.
pub fn report_totals(counts : Array[FileCount]) -> ProjectCount {
  let totals = ProjectCount::default()
  for f in counts {
    totals.files = totals.files + 1
    totals.blank = totals.blank + f.blank
    totals.comment = totals.comment + f.comment
    totals.code = totals.code + f.code
    totals.mixed = totals.mixed + f.mixed
    totals.complexity = totals.complexity + f.complexity
  }
  totals
}

///|
/// Aggregate per-file counts by language, sorted by code lines descending.
pub fn aggregate_by_language(
  counts : Array[FileCount],
) -> Array[(String, ProjectCount)] {
  let groups : Array[(String, ProjectCount)] = []
  for f in counts {
    let mut found = false
    for i = 0; i < groups.length(); i = i + 1 {
      if groups[i].0 == f.language {
        let pc = groups[i].1
        pc.files = pc.files + 1
        pc.blank = pc.blank + f.blank
        pc.comment = pc.comment + f.comment
        pc.code = pc.code + f.code
        pc.mixed = pc.mixed + f.mixed
        pc.complexity = pc.complexity + f.complexity
        found = true
      }
    }
    if !found {
      groups.push(
        (
          f.language,
          {
            files: 1,
            blank: f.blank,
            comment: f.comment,
            code: f.code,
            mixed: f.mixed,
            complexity: f.complexity,
          },
        ),
      )
    }
  }
  sort_groups_desc(groups)
}

///|
/// Sort language groups by code lines descending (stable enough for the
/// small number of languages in a typical project).
fn sort_groups_desc(
  groups : Array[(String, ProjectCount)],
) -> Array[(String, ProjectCount)] {
  let sorted : Array[(String, ProjectCount)] = []
  for g in groups {
    sorted.push(g)
  }
  for i = 0; i < sorted.length(); i = i + 1 {
    for j = i + 1; j < sorted.length(); j = j + 1 {
      if sorted[j].1.code > sorted[i].1.code {
        let tmp = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = tmp
      }
    }
  }
  sorted
}
