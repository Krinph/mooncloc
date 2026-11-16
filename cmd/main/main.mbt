///|
/// mooncloc CLI entry point.
///
/// Counts lines of code, comments and blank lines across a directory tree,
/// with optional cyclomatic complexity analysis and several output formats.

///|
async fn main {
  let cmd = @argparse.Command::Command(
    "mooncloc",
    about="Count lines of code, comments and blank lines with cyclomatic complexity analysis",
    version="0.1.0",
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
  let report = @mooncloc.render_report(all_counts, format, per_file)
  println(report)
}
