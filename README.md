# mooncloc

Count lines of code, comments and blank lines across a directory tree, with
**cyclomatic complexity** analysis, for **MoonBit and 45+ other languages** —
and turn those numbers into a **CI quality gate** by diffing against a saved
baseline.

`mooncloc` is a pure [MoonBit](https://www.moonbitlang.com) implementation of a
code quality tool. It ships as both a **library** (parse and count in your own
MoonBit programs) and a **CLI** (`moon run cmd/main`).

## What makes it different from a line counter

Plain counters (tokei, `TokeiMBT`, cloc) answer *"how much code is there?"*.
mooncloc also answers *"did this change make the code worse, and should CI
block it?"*:

- **`--snapshot`** saves a self-describing baseline (per-file metrics).
- **`--baseline ... --check`** diffs the current tree against it and fails with
  exit code 1 when code/complexity growth or comment-ratio thresholds are
  exceeded — ready for CI.
- **`--baseline tokei-report.json`** reuses a TokeiMBT / tokei JSON report as
  the baseline, so an existing counting step does not need to change.

See [`docs/COMPARISON.md`](docs/COMPARISON.md) for a same-project output
comparison and the reuse/extension/differentiation rationale.

## Features

- **Accurate line counting** — code / comment / blank / mixed lines, with a
  tokenizer that understands comments and string literals per language
  (including multi-line strings, raw strings and nested block comments).
- **Cyclomatic complexity** — counts `if`/`elif`/`match`/`for`/`while`/
  `loop`/`guard`/`catch`/`case`/`when`/`switch` plus `&&`, `||` and `?`.
- **45 languages** — MoonBit, C, C++, C#, Java, JavaScript, JSX,
  TypeScript, TSX, Python, Ruby, Go, Rust, Swift, Kotlin, PHP, Lua, Shell,
  SQL, HTML, CSS, JSON, XML, YAML, TOML, INI, Markdown, Dockerfile, Zig,
  Dart, Haskell, OCaml, Elixir, Perl, R, Julia, Nim, PowerShell, Scala,
  Groovy, Objective-C, Erlang, Clojure, Verilog, Lisp.
- **gitignore-style excludes** — `*`, `?`, `**`, directory patterns and
  anchored patterns; sensible defaults (`.git`, `target`, `_build`,
  `node_modules`, ...).
- **Four output formats** — aligned text table, JSON, CSV and Markdown.
- **Language filtering** — count only the languages you care about.
- **Health metrics** — comment ratio, complexity per 100 code lines and the
  most complex file.
- **Baseline snapshots & regression gate** — save a baseline, diff any later
  tree against it, and fail CI on code/complexity growth or comment-ratio drop.
- **TokeiMBT/tokei baseline import** — reuse an existing counter's JSON report
  as the baseline; complexity rules are skipped honestly when absent.
- **Library + CLI** — a clean public API for embedding, and a full
  command-line tool on top of it.

## Install

### As a library

```text
moon add Krinph/mooncloc
```

### As a CLI

```text
git clone https://github.com/Krinph/mooncloc.git
cd mooncloc
moon run cmd/main -- .
```

Or build a native binary:

```text
moon build --target native cmd/main
```

## Usage

```text
mooncloc [options] [paths...]

Options:
  -f, --format <fmt>      table | json | csv | markdown (default: table)
  -x, --exclude <glob>    exclude pattern, gitignore style (repeatable)
  -l, --language <name>   only count this language (repeatable)
  -H, --hidden            include hidden files
      --all               per-file breakdown in table/JSON/CSV output
      --no-complexity     disable cyclomatic complexity analysis
  -V, --version           print version
  -h, --help              print help

Quality gate (new):
      --snapshot <FILE>   write a baseline snapshot JSON
  -b, --baseline <FILE>   compare current scan to FILE (mooncloc or TokeiMBT JSON)
  -c, --check             with --baseline: fail (exit 1) on a gate violation
      --max-code-growth <N>           allow at most N new code lines
      --max-complexity-growth <N>     allow complexity to grow by at most N
      --min-comment-ratio <PCT>       require comment ratio >= PCT percent
      --max-file-complexity <N>       fail if any file exceeds complexity N
```

### Examples

Count the current project:

```text
$ moon run cmd/main -- .
Language  Files  Blank  Comment  Code  Complexity
--------  -----  -----  -------  ----  ----------
MoonBit      14    168      302  2273         214
Markdown      4     85        0   265          27
YAML          1      6        0    45           4
Rust          1      0        2    13           2
Python        1      5        1     7           0
--------  -----  -----  -------  ----  ----------
Total        21    264      305  2603         247
```

JSON output with per-file detail:

```text
$ moon run cmd/main -- --format json --all .
```

Markdown output (great for READMEs):

```text
$ moon run cmd/main -- --format markdown .
```

Only count Rust, excluding generated code:

```text
$ moon run cmd/main -- --language Rust --exclude "**/generated" .
```

### Quality gate (CI)

Save a baseline of the reviewed state, then gate later changes against it:

```text
$ moon run cmd/main -- --snapshot baseline.json .

# later, in CI:
$ moon run cmd/main -- --baseline baseline.json --check \
    --max-code-growth 50 --max-complexity-growth 10 \
    --min-comment-ratio 10
File                Language  Status  Code  Comment  Blank  Cx
------------------  --------  ------  ----  -------  -----  --
src/hotspot.mbt     MoonBit   changed   +34       +2     +4  +9

files: +0 added, -0 removed, ~1 changed, 12 unchanged
totals: code +34, comment +2, blank +4, complexity +9
quality gate: FAIL (2 violation(s))
  [max_code_growth] code grew by +34 lines (limit +50)
  [max_complexity_growth] complexity grew by +9 (limit +10)
```

The process exits `1` when any rule is violated, `0` otherwise. Use
`-f json` for a machine-readable verdict (`gate_passed`, `violations`).

To reuse an existing counter instead of mooncloc's own baseline, feed it a
TokeiMBT / tokei JSON report directly:

```text
$ moon run cmd/main -- --baseline tokei-report.json --check --max-code-growth 50 .
```

Complexity-based rules are skipped with a visible note when the baseline
source does not carry complexity data.

## Counting rules

`mooncloc` follows the same conventions as the classic `cloc` tool:

- **Code** — lines with actual source code.
- **Comment** — lines that contain only comments (including block-comment
  continuations and `#!/` shebang lines).
- **Blank** — lines with only whitespace.
- **Mixed** — a line with both code and a trailing comment; counted as code
  by default.
- **Complexity** — total number of branch points in the file (control-flow
  keywords plus boolean operators). Comment and string contents are never
  counted.
- Multi-line string literals (`"""..."""`, `#|...|#`, backticks, ...) count
  as code lines, since they are part of the source.
- Files larger than 10 MiB are skipped, and hidden files are ignored unless
  `--hidden` is passed.
- A file that cannot be read is reported as a warning and skipped; it never
  aborts the whole scan.

## Library API

```moonbit
import "Krinph/mooncloc" @mooncloc

let options = @mooncloc.CountOptions::default()
  .with_languages(["MoonBit"])
  .with_exclude(["target/"])
let (counts, errors) = @mooncloc.scan_directory(".", options)
let report = @mooncloc.render_report(counts, @mooncloc.ReportFormat::Table, false)
println(report)
```

Key types: `LanguageDef`, `CountResult`, `FileCount`, `ProjectCount`,
`CountOptions`, `IgnoreRules`, `ReportFormat`, plus the pure functions
`count_text`, `count_complexity` and `language_by_extension`.

Quality-gate API: `snapshot_from_counts`, `snapshot_to_json`,
`snapshot_from_json` (mooncloc and TokeiMBT formats), `diff_snapshots`,
`GatePolicy` (+ builder methods), `evaluate_gate`, `render_diff_table` and
`render_diff_json`.

## Development

```text
moon check
moon test
moon fmt
moon info
```

The test suite covers the tokenizer, complexity analyzer, ignore rules,
report rendering, the quality-gate module (snapshots, TokeiMBT import, diffs
and gate policies) and end-to-end directory scans (57 tests). The project
dogfoods itself: `moon run cmd/main -- .` reports the statistics above.

### Health metrics

With `--all` the table output adds a per-file breakdown plus a health line:

```text
comment ratio: 13%   complexity per 100 code lines: 12   most complex file: samples/fib.rs
```

JSON output includes the same data in a `health` section, and
`most_complex_files` / `comment_ratio` / `complexity_per_code` are public API.

## License

[Apache-2.0](LICENSE)
