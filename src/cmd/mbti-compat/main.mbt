///| Process-exit FFI, one function per real backend -- copied verbatim (down
/// to the exact `#cfg`/extern spelling) from `moonbitlang/parser/cmd/mq`'s
/// own `main.mbt`, the only place in this project's research an exit-code
/// CLI was ever ground-truthed end to end. `native`'s `exit` takes an `Int`;
/// `wasm`'s WASI `proc_exit` takes a `UInt` -- a real difference between the
/// two backends, which is exactly why every call site below passes a bare
/// integer literal straight to `exit(...)` rather than threading an `Int`
/// through a variable: a literal's numeral type resolves independently at
/// each call site to whichever of these two declarations this build
/// actually compiles, so the same source works on both backends without an
/// explicit `Int`/`UInt` conversion anywhere.
#cfg(target="native")
extern "C" fn exit(code : Int) = "exit"

///|
#cfg(target="wasm")
fn exit(code : UInt) = "wasi_snapshot_preview1" "proc_exit"

///| Exit 0 -- Gate 2's design brief: "0 sufficient" (no version bump
/// required). Not `async`: `exit` itself is a plain FFI call, and this
/// function awaits nothing.
fn[T] halt_ok() -> T {
  exit(0)
  panic()
}

///| Exit 1 -- "1 insufficient bump". `run_check`'s `_` branch (no
/// `--declared`/`--baseline-version` given) still uses this for the
/// honestly-scoped M1 subset it can compute without a declared version to
/// compare against: "the delta requires a version bump of some size", not a
/// real sufficiency check. `run_verdict` (M2, see its own doc comment) also
/// calls this, but only after a real `@policy.verdict` computation found the
/// declared version genuinely insufficient -- the exit code means the same
/// thing (a bump is needed), just backed by a real comparison instead of an
/// approximation once `--declared`/`--baseline-version` are both given.
fn[T] halt_bump_required() -> T {
  exit(1)
  panic()
}

///| Exit 2 -- "2 ingest failure": either input file could not be read at all,
/// or was read but failed to parse as `.mbti`. `async` because it writes to
/// stderr first.
async fn[T] die_ingest(message : String) -> T {
  @stdio.stderr.write("\{message}\n") catch {
    _ => ()
  }
  exit(2)
  panic()
}

///| Exit 3 -- "3 usage error": bad arguments (see `cli.mbt`). Also reused for
/// the one I/O failure this CLI has no dedicated exit code for -- stdout
/// itself refusing a write (`write_stdout` below) -- since that is an
/// environmental failure outside the tool's own argument handling or input
/// parsing, not a fourth case Gate 2's four-code scheme accounted for;
/// documented here rather than silently folded in.
async fn[T] die_usage(message : String) -> T {
  @stdio.stderr.write("\{message}\n") catch {
    _ => ()
  }
  exit(3)
  panic()
}

///| Everything in argv after argv[0] -- ground-truthed verbatim from
/// `moonbitlang/parser/cmd/mq/main.mbt`'s `program_args`.
fn program_args() -> ArrayView[String] {
  let args = @env.args()
  if args.length() > 1 {
    args[1:]
  } else {
    []
  }
}

///| Write `message` to stdout, exactly as written (no trailing newline
/// added -- callers that want one include it themselves, since
/// `render_json`'s output and `render_text`'s multi-line output both read
/// more naturally without an extra blank line appended here).
async fn write_stdout(message : String) -> Unit {
  try @stdio.stdout.write(message) catch {
    err => die_usage("error: failed to write to stdout: \{err}")
  } noraise {
    _ => ()
  }
}

///| Read one `.mbti` file's full contents. Same shape as `mq`'s own
/// `read_file`: the `die_ingest(...)` call is made as a statement (its
/// result discarded) and followed by an explicit fallback value, rather than
/// relying on `die_ingest`'s generic return type to unify directly with
/// `String` in tail position -- mirrors the one real precedent this project
/// has for this exact situation instead of gambling on an alternative.
async fn read_mbti_file(path : String) -> String {
  try @fs.read_file(path).text() catch {
    err => {
      die_ingest("error: failed to read \{path}: \{err}")
      ""
    }
  } noraise {
    source => source
  }
}

///| An empty, valid `Surface` -- only ever used as the unreachable-in-
/// practice fallback value in `parse_surface`'s one catch arm (see
/// `read_mbti_file`'s doc comment above for why a concrete fallback is
/// supplied at all).
fn empty_surface() -> @surface.Surface {
  @surface.Surface::{ package_name: "", imports: [], symbols: Map([]) }
}

///| Parse one `.mbti` file's source text (already read from `path` by
/// `read_mbti_file`) into a `Surface`, exiting 2 with a precise message on
/// failure. Deliberately destructures `IngestError`'s one real variant
/// (`Parse(file~, span~, message~)`) to build the error message from its
/// plain `String`/`Int` fields, rather than interpolating the caught
/// `IngestError` value directly via `\{err}` -- this project has no proof
/// `\{}` accepts a `derive(Debug)`-only type (see
/// `gate3-decisions-and-plan.md`'s "not yet proven" notes), and this way
/// sidesteps that question while also giving a more precise message (exact
/// file, byte span, and parser message) than a stringified error value
/// would anyway. Cross-package suberror-variant matching (`@ingest.Parse(
/// ...)`, no `IngestError::` qualifier) is ground-truthed from
/// `moonbitlang/async/src/fs`'s own real `@os_error.OSError(_) as err`
/// pattern -- a suberror's variants are reached the same way a package's
/// other top-level constructors are, not nested under the suberror's own
/// type name.
///
/// This catch has only ONE arm, with no trailing `_ => ...` wildcard: since
/// `of_mbti_source` raises exactly `IngestError`, and `IngestError` has
/// exactly one variant (`Parse`), matching that one unguarded constructor is
/// already exhaustive -- a trailing wildcard here would itself be dead code,
/// not a safety net. Ground-truthed from `moonbitlang/parser`'s own compiler
/// test suite (`test/sync_test/__snapshot__/pipeline_test_error_no_payload
/// .mbt`), which catches a single-variant suberror (`ConstantError`) with a
/// bare one-arm `catch { ConstantError => ... }` and only adds a `_ =>` arm
/// once the raise type widens to the general `Error` union. An earlier draft
/// of this function added a `_ =>` arm "just in case" with a duplicate
/// `die_ingest(...); empty_surface()` body -- the real `moon check` flagged
/// that second arm's `empty_surface()` as `[0012] unreachable_code`, which is
/// this same fact (the wildcard can never be reached) surfacing as a
/// compiler warning rather than a type error.
async fn parse_surface(path : String, source : String) -> @surface.Surface {
  try @ingest.of_mbti_source(source, name=path) catch {
    @ingest.Parse(file~, span~, message~) => {
      die_ingest(
        "error: failed to parse \{file} (\{span.start}-\{span.end}): \{message}",
      )
      empty_surface()
    }
  } noraise {
    surface => surface
  }
}

///| The whole `check` pipeline: read both files, parse both, compare, render,
/// print, then either the M1-era exit-code approximation (0/1 depending on
/// whether the resulting `Delta` needs a version bump at all -- see
/// `halt_bump_required`'s doc comment) or, when both `options.declared` and
/// `options.baseline_version` were given, Gate 2's real sufficient/
/// insufficient verdict (see `run_verdict`'s own doc comment) -- the follow-
/// up step `src/policy`'s own section named as still needing a baseline-
/// version flag design before it could be wired in.
async fn run_check(options : CheckOptions) -> Unit {
  let old_source = read_mbti_file(options.old_path)
  let new_source = read_mbti_file(options.new_path)
  let old_surface = parse_surface(options.old_path, old_source)
  let new_surface = parse_surface(options.new_path, new_source)
  let delta = @compare.compare(old=old_surface, new=new_surface)
  // `--json` wins if both `--json` and `--markdown` are given -- `cli.mbt`'s
  // own `CheckOptions` doc comment documents this precedence; `parse_check`
  // deliberately doesn't treat the combination as a usage error, matching
  // how `--color` was already silently allowed (and ignored) alongside
  // `--json` before this round.
  let output = if options.json {
    @report.render_json(delta).stringify()
  } else if options.markdown {
    @report.render_markdown(delta)
  } else {
    @report.render_text(delta, color=options.color)
  }
  write_stdout("\{output}\n")
  match (options.declared, options.baseline_version) {
    (Some(declared_raw), Some(baseline_raw)) =>
      run_verdict(
        declared_raw,
        baseline_raw,
        delta,
        json=options.json,
        markdown=options.markdown,
      )
    _ =>
      // Fully-qualified `@compare.Level::Patch`, not a bare `Patch` -- this
      // file has no `using @compare { type Level }` block, and one `==`
      // check is a one-off not worth adding one for (same reasoning
      // `inverse_and_noise_wbtest.mbt` and `core_drift_wbtest.mbt` already
      // used for constructor access elsewhere in this project).
      if delta.level() == @compare.Level::Patch {
        halt_ok()
      } else {
        halt_bump_required()
      }
  }
}

///| Parse one `--declared`/`--baseline-version` argument into a
/// `@policy.Version`, exiting 3 via `die_usage` on a malformed one.
/// Deliberately supplies an explicit fallback value in the one catch arm
/// (`@policy.Version::{ major: 0, minor: 0, patch: 0 }`, the same
/// `@pkg.Type::{ field: value, ... }` struct-literal shape `main.mbt`'s own
/// `empty_surface` already uses to build a `@surface.Surface` from outside
/// its defining package) rather than relying on `die_usage`'s generic return
/// type unifying directly with `@policy.Version` in tail position -- the
/// same caution `read_mbti_file`'s own doc comment already explains for a
/// non-`Unit` return type, reused here for a second, unrelated non-`Unit`
/// return type.
async fn parse_version_arg(raw : String, flag_name : String) -> @policy.Version {
  try @policy.Version::parse(raw) catch {
    @policy.InvalidFormat(raw=bad) => {
      die_usage(
        "error: invalid version for \{flag_name}: \"\{bad}\" (expected MAJOR.MINOR.PATCH)",
      )
      @policy.Version::{ major: 0, minor: 0, patch: 0 }
    }
  } noraise {
    version => version
  }
}

///| Gate 2's real "is the declared version bump sufficient?" verdict --
/// replaces the M1-era exit-code approximation (`halt_ok`/
/// `halt_bump_required` in `run_check`'s own `_` branch) for the specific
/// case where the caller supplied both `--declared` and `--baseline-version`
/// (`parse_check` rejects supplying only one of the two -- see `cli.mbt`).
/// Parses both raw strings (`parse_version_arg`, exit 3 on a malformed one),
/// computes `@policy.verdict`, prints one line/object reporting the result,
/// and exits 0 for `Sufficient` or 1 for `Insufficient`, matching Gate 2's
/// design brief's actual "0 sufficient, 1 insufficient bump" semantics for
/// the first time in this project (everywhere else, exit 0/1 has only ever
/// meant the honestly-scoped M1 approximation "no bump needed"/"some bump
/// needed", documented as such in `halt_bump_required`'s own doc comment).
///
/// **Deliberately prints a second, separate line/JSON object after the
/// delta's own `--json`/`--markdown`/text rendering, rather than folding the
/// verdict into `render_json`/`render_markdown`/`render_text` themselves.**
/// Those three renderers are Gate 2's own named signatures, operating on
/// `Delta` alone (`report`'s own package has no dependency on `policy` and
/// this project isn't adding one for a CLI-only concern); a verdict only
/// exists when `--declared`/`--baseline-version` were both given, so it's
/// necessarily optional in a way none of `Delta`'s own fields are. In
/// `--json` mode this makes stdout two newline-delimited JSON objects (the
/// delta, then the verdict) rather than one combined document -- a
/// deliberate, documented choice (see `usage()`'s own text) rather than an
/// oversight, and still trivially machine-parseable line by line (the same
/// "JSON Lines" shape many real CLI tools already use for this kind of
/// "here's the main report, plus one more small fact" output).
async fn run_verdict(
  declared_raw : String,
  baseline_raw : String,
  delta : @compare.Delta,
  json~ : Bool,
  markdown~ : Bool,
) -> Unit {
  let declared = parse_version_arg(declared_raw, "--declared")
  let baseline = parse_version_arg(baseline_raw, "--baseline-version")
  match @policy.verdict(baseline~, declared~, delta~) {
    @policy.Verdict::Sufficient(_) => {
      // The `Json::object({...})` value is built into a `let` first, then
      // interpolated on a single line (`"\{verdict_json.stringify()}\n"`) --
      // the same single-line-interpolation shape `run_check`'s own `output`
      // binding already uses, rather than nesting the multi-line map literal
      // directly inside a `\{...}` interpolation (this project has no proof
      // a string interpolation block itself can safely span multiple
      // physical lines, so this sidesteps the question entirely).
      if json {
        let verdict_json = Json::object({
          "verdict": Json::string("sufficient"),
          "declared": Json::string(declared.to_string()),
        })
        write_stdout("\{verdict_json.stringify()}\n")
      } else if markdown {
        write_stdout(
          "\n**Verdict:** sufficient -- declared `\{declared.to_string()}` covers this change.\n",
        )
      } else {
        write_stdout(
          "Verdict: sufficient -- declared \{declared.to_string()} covers this change.\n",
        )
      }
      halt_ok()
    }
    @policy.Verdict::Insufficient(required~, declared~) => {
      if json {
        let verdict_json = Json::object({
          "verdict": Json::string("insufficient"),
          "declared": Json::string(declared.to_string()),
          "required": Json::string(required.to_string()),
        })
        write_stdout("\{verdict_json.stringify()}\n")
      } else if markdown {
        write_stdout(
          "\n**Verdict:** insufficient -- declared `\{declared.to_string()}`, at least `\{required.to_string()}` is required.\n",
        )
      } else {
        write_stdout(
          "Verdict: insufficient -- declared \{declared.to_string()}, at least \{required.to_string()} is required.\n",
        )
      }
      halt_bump_required()
    }
  }
}

///| `--explain <rule-id>`: print a short explanation of one classification
/// rule id and exit 0, or exit 3 -- reusing the usage-error code, since
/// Gate 2's four-code scheme has no dedicated case for "unrecognized rule
/// id" and an unrecognized id is, at bottom, a bad argument -- if
/// `@compare.explain` doesn't recognize it.
///
/// `@compare.RuleId(rule_id)`, a plain tuple-struct constructor call across
/// the package boundary, is ground-truthed verbatim from
/// `src/ingest/ingest.mbt`'s own real, already-compiling
/// `@surface.SymbolId(f.name.name)` -- `SymbolId` and `RuleId` are both
/// `pub(all) struct Name(String)` tuple-struct newtypes, so the same
/// cross-package call syntax applies to both.
async fn run_explain(rule_id : String) -> Unit {
  match @compare.explain(@compare.RuleId(rule_id)) {
    Some(text) => {
      write_stdout("\{text}\n")
      halt_ok()
    }
    None => die_usage("error: unknown rule id: \{rule_id}")
  }
}

///|
async fn main {
  match parse_cli(program_args()) {
    Help(text) => write_stdout("\{text}\n")
    Error(message) => die_usage(message)
    RunCheck(options) => run_check(options)
    Explain(rule_id) => run_explain(rule_id)
  }
}
