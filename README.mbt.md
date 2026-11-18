# Krinph/mooncloc

Code quality regression gate for MoonBit: baseline snapshots, diff and CI
gating on top of line/complexity statistics (45+ languages).

- Accurate tokenizer per language (comments, multi-line strings, raw strings)
- Cyclomatic complexity analysis
- Baseline snapshots + regression diff + CI quality gate
- Import TokeiMBT/tokei JSON reports as baselines
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
