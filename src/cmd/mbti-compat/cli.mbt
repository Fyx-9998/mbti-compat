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
  Help(String)
  Error(String)
}

///| Parsed, validated arguments for `mbti-compat check <old.mbti> <new.mbti>`.
struct CheckOptions {
  old_path : String
  new_path : String
  json : Bool
  color : Bool
}

///| `mbti-compat`'s only real command today (M1). Gate 2's roadmap sketched
/// `report` alongside `check`, but `render_text`/`render_json` (`src/report`)
/// are exactly what `check`'s own `--json` flag already exposes -- a
/// separate subcommand would not have added anything a flag doesn't already
/// cover, so only `check` is implemented.
fn usage() -> String {
  (
    #|Usage: mbti-compat check [options] <old.mbti> <new.mbti>
    #|
    #|Compare two .mbti files and report the classified differences.
    #|
    #|Arguments:
    #|  <old.mbti>  Path to the old (baseline) .mbti file
    #|  <new.mbti>  Path to the new .mbti file
    #|
    #|Options:
    #|  -h, --help  Show help information.
    #|  --json      Print the delta as JSON instead of text.
    #|  --color     Colorize text output with ANSI escape codes (off by
    #|              default -- this build has no proven way to detect
    #|              whether stdout is a terminal, so it never guesses).
    #|
    #|Exit codes:
    #|  0  no version bump required
    #|  1  a version bump is required
    #|  2  one of the input files could not be read or parsed as .mbti
    #|  3  usage error (bad arguments)
  )
}

fn is_help_arg(arg : String) -> Bool {
  arg == "-h" || arg == "--help"
}

fn cli_error(message : String) -> CliAction {
  Error("error: \{message}\n\n\{usage()}")
}

///| Entry point for the whole command line (everything after argv[0]).
fn parse_cli(args : ArrayView[String]) -> CliAction {
  if args.length() == 0 {
    return cli_error("expected subcommand: check")
  }
  let first = args[0]
  if is_help_arg(first) {
    return Help(usage())
  }
  if first != "check" {
    return cli_error("unknown subcommand: \{first}")
  }
  parse_check(args[1:])
}

fn parse_check(args : ArrayView[String]) -> CliAction {
  let mut old_path : String? = None
  let mut new_path : String? = None
  let mut json = false
  let mut color = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if is_help_arg(arg) {
      return Help(usage())
    } else if arg == "--json" {
      json = true
      i = i + 1
    } else if arg == "--color" {
      color = true
      i = i + 1
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
  match old_path {
    None => cli_error("missing <old.mbti> and <new.mbti>")
    Some(old) =>
      match new_path {
        None => cli_error("missing <new.mbti>")
        Some(new) => RunCheck({ old_path: old, new_path: new, json, color })
      }
  }
}
