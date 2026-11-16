# Krinph/mooncloc

Count lines of code, comments and blank lines with cyclomatic complexity
analysis, for MoonBit and 30+ other languages.

- Accurate tokenizer per language (comments, multi-line strings, raw strings)
- Cyclomatic complexity analysis
- gitignore-style excludes and language filters
- table / JSON / CSV / Markdown output
- Library API + CLI

## Install

```text
moon add Krinph/mooncloc
```

## Example

```moonbit nocheck
import "Krinph/mooncloc" @mooncloc

let options = @mooncloc.CountOptions::default()
let (counts, errors) = @mooncloc.scan_directory(".", options)
let report = @mooncloc.render_report(counts, @mooncloc.ReportFormat::Table, false)
println(report)
```

Run the CLI:

```text
moon run cmd/main -- .
```

## License

Apache-2.0
