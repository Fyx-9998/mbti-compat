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

///| Exit 1 -- "1 insufficient bump". M1 has no `--declared`/`src/policy` yet
/// (both are M2), so there is no declared bump to compare against -- this
/// build uses exit 1 for the honestly-scoped subset it *can* compute today:
/// "the delta requires a version bump of some size", full declared-vs-
/// required comparison deferred to M2 without renumbering the exit codes.
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
/// print, exit 0 or 1 depending on whether the resulting `Delta` needs a
/// version bump at all (see `halt_bump_required`'s doc comment for the exact,
/// M1-scoped meaning of exit 1 today).
async fn run_check(options : CheckOptions) -> Unit {
  let old_source = read_mbti_file(options.old_path)
  let new_source = read_mbti_file(options.new_path)
  let old_surface = parse_surface(options.old_path, old_source)
  let new_surface = parse_surface(options.new_path, new_source)
  let delta = @compare.compare(old=old_surface, new=new_surface)
  let output = if options.json {
    @report.render_json(delta).stringify()
  } else {
    @report.render_text(delta, color=options.color)
  }
  write_stdout("\{output}\n")
  // Fully-qualified `@compare.Level::Patch`, not a bare `Patch` -- this file
  // has no `using @compare { type Level }` block, and one `==` check is a
  // one-off not worth adding one for (same reasoning `inverse_and_noise_
  // wbtest.mbt` and `core_drift_wbtest.mbt` already used for constructor
  // access elsewhere in this project).
  if delta.level() == @compare.Level::Patch {
    halt_ok()
  } else {
    halt_bump_required()
  }
}

///|
async fn main {
  match parse_cli(program_args()) {
    Help(text) => write_stdout("\{text}\n")
    Error(message) => die_usage(message)
    RunCheck(options) => run_check(options)
  }
}
