///| One parsed command line: either something to run, help text to print, or
/// a usage error to report. Kept entirely free of I/O (no file reads, no
/// `@env.args()` call anywhere in this file) so it can be unit-tested with
/// plain, synchronous `test { ... }` blocks -- `main.mbt` is the only file
/// that touches argv or the filesystem, mirroring
/// `moonbitlang/parser/cmd/mq`'s own `cli.mbt`/`main.mbt` split (ground-
/// truthed by cloning that repo directly -- see
/// `gate3-decisions-and-plan.md`'s "Real syntax/API corrections" section).
enum CliAction {
  RunCheck(CheckOptions)
  Explain(String)
  Help(String)
  Error(String)
}

///| Parsed, validated arguments for `mbti-compat check <old.mbti> <new.mbti>`.
/// `json` and `markdown` are independent flags, not a single output-format
/// enum -- matching how `json`/`color` were already independent booleans
/// before this round. If both `json` and `markdown` are given, `main.mbt`'s
/// `run_check` picks JSON first (documented there, not here) rather than
/// treating the combination as a usage error -- the same "don't validate a
/// combination nothing asked for" precedent `color` already set by being
/// silently ignored whenever `json` is also set.
///
/// `declared`/`baseline_version` are the raw, unparsed strings from
/// `--declared <version>`/`--baseline-version <version>` (both `None` unless
/// given) -- deliberately not parsed into `@policy.Version` here. `cli.mbt`
/// stays pure (no `raise`, no I/O) throughout this whole file, and
/// `Version::parse` raises; `main.mbt`'s `run_verdict` is where the real
/// parsing (and its exit-3-on-malformed-input handling) happens, matching
/// the same cli.mbt-parses-shape/main.mbt-parses-semantics split
/// `read_mbti_file`/`parse_surface` already established for file paths. When
/// both are given, `main.mbt`'s `run_check` computes Gate 2's real
/// sufficient/insufficient verdict instead of the M1-era exit-code
/// approximation -- see `run_verdict`'s own doc comment. `parse_check`
/// itself still enforces that the two are given together, not separately
/// (see its own doc comment) -- that's a pure shape constraint on the
/// argument list, not semantic version validation, so it belongs here.
struct CheckOptions {
  old_path : String
  new_path : String
  json : Bool
  markdown : Bool
  color : Bool
  declared : String?
  baseline_version : String?
}

///| `mbti-compat`'s real commands today (M1's `check`, plus M2's first CLI-
/// wired addition, `--explain <rule-id>`). Gate 2's roadmap sketched `report`
/// alongside `check`, but `render_text`/`render_json` (`src/report`) are
/// exactly what `check`'s own `--json` flag already exposes -- a separate
/// subcommand would not have added anything a flag doesn't already cover, so
/// only `check` is implemented as a subcommand. `--explain` is a top-level
/// flag rather than a subcommand of its own: Gate 2's design brief names it
/// as exactly that (`--explain <rule>`), and `src/compare/explain.mbt`'s own
/// doc comment says the same ("for `--explain <rule>`").
fn usage() -> String {
  (
    #|Usage: mbti-compat check [options] <old.mbti> <new.mbti>
    #|       mbti-compat --explain <rule-id>
    #|
    #|Compare two .mbti files and report the classified differences, or look
    #|up a short explanation for one classification rule id (the id printed
    #|alongside each change in check's own output).
    #|
    #|Arguments:
    #|  <old.mbti>  Path to the old (baseline) .mbti file
    #|  <new.mbti>  Path to the new .mbti file
    #|  <rule-id>   A rule id such as "sym-removed" (see check's output for
    #|              the id attached to each reported change)
    #|
    #|Options:
    #|  -h, --help        Show help information.
    #|  --json            Print the delta as JSON instead of text.
    #|  --markdown        Print the delta as Markdown (for a PR comment)
    #|                    instead of text. If both --json and --markdown are
    #|                    given, --json wins.
    #|  --color           Colorize text output with ANSI escape codes (off by
    #|                    default -- this build has no proven way to detect
    #|                    whether stdout is a terminal, so it never guesses).
    #|                    Has no effect on --json or --markdown output.
    #|  --declared <version>
    #|                    The version you intend to publish, e.g. 1.3.0. Must
    #|                    be given together with --baseline-version (each
    #|                    requires the other). When both are given, check
    #|                    reports whether --declared is a sufficient bump
    #|                    over --baseline-version for this change, instead of
    #|                    just whether some bump is required.
    #|  --baseline-version <version>
    #|                    The currently-published version, e.g. 1.2.0. See
    #|                    --declared above.
    #|  --explain <rule-id>
    #|                    Print a short explanation of one rule id and exit,
    #|                    instead of comparing any files.
    #|
    #|Exit codes:
    #|  0  no version bump required; or, with --declared/--baseline-version,
    #|     --declared is a sufficient bump; or --explain recognized the rule
    #|     id
    #|  1  a version bump is required; or, with --declared/--baseline-version,
    #|     --declared is not a sufficient bump
    #|  2  one of the input files could not be read or parsed as .mbti
    #|  3  usage error (bad arguments); --declared or --baseline-version was
    #|     given without the other, or with a malformed version string; or
    #|     --explain was given an id this build doesn't recognize
  )
}

fn is_help_arg(arg : String) -> Bool {
  arg == "-h" || arg == "--help"
}

fn cli_error(message : String) -> CliAction {
  Error("error: \{message}\n\n\{usage()}")
}

///| Entry point for the whole command line (everything after argv[0]).
/// `--explain` is checked before the `check`-subcommand check below: it's a
/// top-level flag, not a subcommand, so it must not fall through to "unknown
/// subcommand: --explain".
fn parse_cli(args : ArrayView[String]) -> CliAction {
  if args.length() == 0 {
    return cli_error("expected subcommand: check")
  }
  let first = args[0]
  if is_help_arg(first) {
    return Help(usage())
  }
  if first == "--explain" {
    return parse_explain(args[1:])
  }
  if first != "check" {
    return cli_error("unknown subcommand: \{first}")
  }
  parse_check(args[1:])
}

///| Parse `--explain`'s own argument: exactly one rule id, no options of its
/// own. `-h`/`--help` in that one slot still shows help (consistent with
/// `parse_check`'s own `-h` handling), rather than being treated as a
/// (nonsensical) literal rule id to look up.
fn parse_explain(args : ArrayView[String]) -> CliAction {
  if args.length() == 0 {
    return cli_error("--explain requires a <rule-id> argument")
  }
  let first = args[0]
  if is_help_arg(first) {
    return Help(usage())
  }
  if args.length() > 1 {
    return cli_error("unexpected argument: \{args[1]}")
  }
  Explain(first)
}

///| `--declared <version>` and `--baseline-version <version>` are the first
/// two-token (`--flag value`) options this CLI has needed -- every prior
/// option (`--json`, `--markdown`, `--color`) was a bare boolean switch. The
/// `if i + 1 >= args.length() { return cli_error(...) }; ...; i = i + 2;
/// continue` shape for each is ground-truthed verbatim from
/// `moonbitlang/parser/cmd/mq/cli.mbt`'s real `parse_legacy` (its
/// `--file-type`/`-c`/`--output` handling) -- the same file this project's
/// `while`-loop/`ArrayView` slicing pattern was already ground-truthed from,
/// just the `continue` branch that pattern predicted `mbti-compat` would
/// eventually need once it grew a non-boolean flag (see this project's own
/// "Real syntax/API corrections" notes on `while` loops).
fn parse_check(args : ArrayView[String]) -> CliAction {
  let mut old_path : String? = None
  let mut new_path : String? = None
  let mut json = false
  let mut markdown = false
  let mut color = false
  let mut declared : String? = None
  let mut baseline_version : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if is_help_arg(arg) {
      return Help(usage())
    } else if arg == "--json" {
      json = true
      i = i + 1
    } else if arg == "--markdown" {
      markdown = true
      i = i + 1
    } else if arg == "--color" {
      color = true
      i = i + 1
    } else if arg == "--declared" {
      if i + 1 >= args.length() {
        return cli_error("missing value for --declared")
      }
      declared = Some(args[i + 1])
      i = i + 2
      continue
    } else if arg == "--baseline-version" {
      if i + 1 >= args.length() {
        return cli_error("missing value for --baseline-version")
      }
      baseline_version = Some(args[i + 1])
      i = i + 2
      continue
    } else if arg.has_prefix("-") && arg != "-" {
      return cli_error("unknown option: \{arg}")
    } else if old_path is None {
      old_path = Some(arg)
      i = i + 1
    } else if new_path is None {
      new_path = Some(arg)
      i = i + 1
    } else {
      return cli_error("unexpected argument: \{arg}")
    }
  }
  // `--declared`/`--baseline-version` are only meaningful together (see
  // `CheckOptions`'s own doc comment) -- rejected here, as a pure shape
  // constraint on the argument list. Plain `is Some(_)`/`is None` boolean
  // checks read more directly than a `match (declared, baseline_version) {
  // ... }` tuple match would for a two-armed "exactly one is missing" check
  // like this (`src/compare/compare.mbt`'s own `diff_symbol` already proves
  // the tuple-match form real and compiling for its four-armed
  // `(Option, Option)` case, reused directly in `main.mbt`'s `run_check`
  // for its simpler two-armed "both given or neither" dispatch).
  if declared is Some(_) && baseline_version is None {
    return cli_error("--declared requires --baseline-version to also be given")
  }
  if baseline_version is Some(_) && declared is None {
    return cli_error("--baseline-version requires --declared to also be given")
  }
  match old_path {
    None => cli_error("missing <old.mbti> and <new.mbti>")
    Some(old) =>
      match new_path {
        None => cli_error("missing <new.mbti>")
        Some(new) =>
          RunCheck({
            old_path: old,
            new_path: new,
            json,
            markdown,
            color,
            declared,
            baseline_version,
          })
      }
  }
}
