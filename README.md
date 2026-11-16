# mooncloc

Count lines of code, comments and blank lines across a directory tree, with
**cyclomatic complexity** analysis, for **MoonBit and 30+ other languages**.

`mooncloc` is a pure [MoonBit](https://www.moonbitlang.com) implementation of a
cloc-style code statistics tool. It ships as both a **library** (parse and
count in your own MoonBit programs) and a **CLI** (`moon run cmd/main`).

## Features

- 📊 **Accurate line counting** — code / comment / blank / mixed lines, with a
  tokenizer that understands comments and string literals per language
  (including multi-line strings, raw strings and nested block comments).
- 🌀 **Cyclomatic complexity** — counts `if`/`elif`/`match`/`for`/`while`/
  `loop`/`guard`/`catch`/`case`/`when`/`switch` plus `&&`, `||` and `?`.
- 🌐 **30+ languages** — MoonBit, C, C++, C#, Java, JavaScript, JSX,
  TypeScript, TSX, Python, Ruby, Go, Rust, Swift, Kotlin, PHP, Lua, Shell,
  SQL, HTML, CSS, JSON, XML, YAML, TOML, INI, Markdown, Dockerfile, Zig,
  Dart, Haskell, OCaml, Elixir.
- 📁 **gitignore-style excludes** — `*`, `?`, `**`, directory patterns and
  anchored patterns; sensible defaults (`.git`, `target`, `_build`,
  `node_modules`, ...).
- 📋 **Four output formats** — aligned text table, JSON, CSV and Markdown.
- 🔍 **Language filtering** — count only the languages you care about.
- 📚 **Library + CLI** — a clean public API for embedding, and a full
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
      --all               per-file breakdown in JSON/CSV output
      --no-complexity     disable cyclomatic complexity analysis
  -V, --version           print version
  -h, --help              print help
```

### Examples

Count the current project:

```text
$ moon run cmd/main -- .
Language  Files  Blank  Comment  Code  Complexity
--------  -----  -----  -------  ----  ----------
MoonBit      16    149      300  1948         237
Markdown     2      2        0    31           0
--------  -----  -----  -------  ----  ----------
Total       18    151      300  1979         237
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

## Counting rules

`mooncloc` follows the same conventions as the classic `cloc` tool:

- **Code** — lines with actual source code.
- **Comment** — lines that contain only comments (including block-comment
  continuations and `#!/` shebang lines).
- **Blank** — lines with only whitespace.
- **Mixed** — a line with both code and a trailing comment; counted as code
  by default (`--no-mixed-as-code` may change this in future releases).
- **Complexity** — total number of branch points in the file (control-flow
  keywords plus boolean operators). Comment and string contents are never
  counted.
- Multi-line string literals (`"""..."""`, `#|...|#`, backticks, ...) count
  as code lines, since they are part of the source.
- Files larger than 10 MiB are skipped, and hidden files are ignored unless
  `--hidden` is passed.

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

## Development

```text
moon check
moon test
moon fmt
moon info
```

The test suite covers the tokenizer, complexity analyzer, ignore rules,
report rendering and end-to-end directory scans (36+ tests). The project
dogfoods itself: `moon run cmd/main -- .` reports the statistics above.

## License

[Apache-2.0](LICENSE)
