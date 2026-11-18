///|
/// mooncloc CLI entry point.
///
/// Two modes:
///   * `count` (default): one-shot code/comment/complexity statistics.
///   * quality gate: save a baseline snapshot, or compare the current tree
///     against a baseline (mooncloc or TokeiMBT JSON) and fail CI on regression.
///
/// The gate mode is the differentiator over a plain line counter: it turns a
/// static count into a temporal, automatable decision.

///|
async fn main {
  let cmd = @argparse.Command::Command(
    "mooncloc",
    about="Count lines of code with cyclomatic complexity, and gate CI on regressions",
    version="0.2.0",
    arg_required_else_help=true,
    options=[
      @argparse.OptionArg::OptionArg(
        "format",
        short='f',
        long="format",
        about="output format: table, json, csv or markdown",
        default_values=["table"],
      ),
      @argparse.OptionArg::OptionArg(
        "exclude",
        short='x',
        long="exclude",
        about="exclude pattern (gitignore style, repeatable)",
        action=@argparse.OptionAction::Append,
      ),
      @argparse.OptionArg::OptionArg(
        "language",
        short='l',
        long="language",
        about="only count this language (repeatable)",
        action=@argparse.OptionAction::Append,
      ),
      @argparse.OptionArg::OptionArg(
        "max-complexity",
        short='m',
        long="max-complexity",
        about="fail (exit 1) if any file exceeds this complexity",
      ),
      @argparse.OptionArg::OptionArg(
        "snapshot",
        long="snapshot",
        about="write a baseline snapshot JSON to FILE",
      ),
      @argparse.OptionArg::OptionArg(
        "baseline",
        short='b',
        long="baseline",
        about="compare current scan to FILE (mooncloc or TokeiMBT JSON)",
      ),
      @argparse.OptionArg::OptionArg(
        "max-code-growth",
        long="max-code-growth",
        about="gate: allow at most N new code lines (use with --baseline)",
      ),
      @argparse.OptionArg::OptionArg(
        "max-complexity-growth",
        long="max-complexity-growth",
        about="gate: allow complexity to grow by at most N (use with --baseline)",
      ),
      @argparse.OptionArg::OptionArg(
        "min-comment-ratio",
        long="min-comment-ratio",
        about="gate: require comment ratio >= N percent (use with --baseline)",
      ),
      @argparse.OptionArg::OptionArg(
        "max-file-complexity",
        long="max-file-complexity",
        about="gate: fail if any file exceeds complexity N (use with --baseline)",
      ),
    ],
    flags=[
      @argparse.FlagArg::FlagArg(
        "hidden",
        short='H',
        long="hidden",
        about="include hidden files and directories",
      ),
      @argparse.FlagArg::FlagArg(
        "all",
        long="all",
        about="include a per-file breakdown in JSON/CSV output",
      ),
      @argparse.FlagArg::FlagArg(
        "no-complexity",
        long="no-complexity",
        about="disable cyclomatic complexity analysis",
      ),
      @argparse.FlagArg::FlagArg(
        "check",
        short='c',
        long="check",
        about="with --baseline: evaluate the quality gate and exit 1 on violation",
      ),
    ],
    positionals=[
      @argparse.PositionArg::PositionArg(
        "paths",
        about="directories to scan (default: current directory)",
        num_args=@argparse.ValueRange::ValueRange(lower=0),
      ),
    ],
  )
  let outcome = cmd.parse_outcome(argv=@env.args()[1:])
  match outcome {
    @argparse.ParseOutcome::Parsed(matches) => run(matches)
    @argparse.ParseOutcome::Help(text) => println(text)
    @argparse.ParseOutcome::Version(text) => println(text)
    @argparse.ParseOutcome::Failed(err) => println("error: " + err.to_string())
  }
}

///|
/// Parse an integer option value, returning None when absent or invalid.
fn opt_int(matches : @argparse.Matches, name : String) -> Int32? {
  let values = matches.values.get(name).unwrap_or([])
  if values.length() == 0 {
    return None
  }
  let parsed = Some(@string.parse_int(values[0])) catch { _ => None }
  parsed
}

///|
fn opt_double(matches : @argparse.Matches, name : String) -> Double? {
  let values = matches.values.get(name).unwrap_or([])
  if values.length() == 0 {
    return None
  }
  Some(@string.parse_double(values[0])) catch {
    _ => None
  }
}

///|
fn opt_string(matches : @argparse.Matches, name : String) -> String? {
  let values = matches.values.get(name).unwrap_or([])
  if values.length() == 0 {
    None
  } else {
    Some(values[0])
  }
}

///|
async fn run(matches : @argparse.Matches) -> Unit {
  let format = @mooncloc.format_by_name(
    matches.values.get("format").unwrap_or(["table"])[0],
  )
  let paths = matches.values.get("paths").unwrap_or(["."])
  let excludes = matches.values.get("exclude").unwrap_or([])
  let languages = matches.values.get("language").unwrap_or([])
  let include_hidden = matches.flags.get("hidden").unwrap_or(false)
  let per_file = matches.flags.get("all").unwrap_or(false)
  let no_complexity = matches.flags.get("no-complexity").unwrap_or(false)
  let options = @mooncloc.CountOptions::default()
    .with_hidden(include_hidden)
    .with_exclude(excludes)
    .with_languages(languages)
    .with_complexity(!no_complexity)
  let all_counts : Array[@mooncloc.FileCount] = []
  for p in paths {
    let (counts, errors) = @mooncloc.scan_directory(p, options)
    for c in counts {
      all_counts.push(c)
    }
    for e in errors {
      println("warning: " + e)
    }
  }

  // Mode 1: capture a baseline snapshot (no diff needed).
  match opt_string(matches, "snapshot") {
    Some(snapshot_path) => {
      let snapshot = @mooncloc.snapshot_from_counts(all_counts)
      @fs.write_text(snapshot_path, @mooncloc.snapshot_to_json(snapshot))
      println(
        "baseline snapshot written to " +
        snapshot_path +
        " (" +
        all_counts.length().to_string() +
        " files)",
      )
      return
    }
    None => ()
  }

  // Mode 2: compare against a baseline and (optionally) gate CI.
  match opt_string(matches, "baseline") {
    Some(baseline_path) => {
      let baseline_text = Some(@fs.read_text(baseline_path)) catch { _ => None }
      let baseline_snapshot = match baseline_text {
        Some(text) => @mooncloc.snapshot_from_json(text)
        None => None
      }
      match baseline_snapshot {
        None => {
          println(
            "error: cannot read a mooncloc or TokeiMBT baseline from " +
            baseline_path,
          )
          @env.exit(2)
        }
        Some(base) => {
          let current = @mooncloc.snapshot_from_counts(all_counts)
          let diff = @mooncloc.diff_snapshots(base, current)
          let policy = @mooncloc.GatePolicy::default()
          let policy = match opt_int(matches, "max-code-growth") {
            Some(n) => policy.with_max_code_growth(n)
            None => policy
          }
          let policy = match opt_int(matches, "max-complexity-growth") {
            Some(n) => policy.with_max_complexity_growth(n)
            None => policy
          }
          let policy = match opt_double(matches, "min-comment-ratio") {
            Some(n) => policy.with_min_comment_ratio(n)
            None => policy
          }
          let policy = match opt_int(matches, "max-file-complexity") {
            Some(n) => policy.with_max_file_complexity(n)
            None => policy
          }
          let check = matches.flags.get("check").unwrap_or(false)
          let violations = if check {
            @mooncloc.evaluate_gate(policy, diff, current)
          } else {
            []
          }
          let skipped = @mooncloc.complexity_rules_skipped(diff, current)
          match format {
            @mooncloc.ReportFormat::Json =>
              println(@mooncloc.render_diff_json(diff, violations, skipped))
            _ => {
              println(@mooncloc.render_diff_table(diff))
              if check {
                println(@mooncloc.render_gate(violations, skipped))
              }
            }
          }
          if check && violations.length() > 0 {
            @env.exit(1)
          }
        }
      }
      return
    }
    None => ()
  }

  // Mode 3: default one-shot report.
  let report = @mooncloc.render_report(all_counts, format, per_file)
  println(report)
  // Absolute complexity gate: when --max-complexity is given, any file
  // exceeding the limit fails the run with a non-zero exit code.
  match opt_int(matches, "max-complexity") {
    Some(limit) =>
      if limit > 0 {
        let over = @mooncloc.files_over_complexity(all_counts, limit)
        if over.length() > 0 {
          println("")
          println(
            "complexity gate FAILED: " +
            over.length().to_string() +
            " file(s) exceed limit " +
            limit.to_string(),
          )
          for f in over {
            println(
              "  " + f.path + " (complexity " + f.complexity.to_string() + ")",
            )
          }
          @env.exit(1)
        } else {
          println("complexity gate passed (limit " + limit.to_string() + ")")
        }
      }
    None => ()
  }
}
