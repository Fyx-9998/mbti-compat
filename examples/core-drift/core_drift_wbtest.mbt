///| The two real `moonbitlang/core/argparse` `.mbti` snapshots vendored
/// verbatim in this directory (`argparse-f8806e9.mbti`, `argparse-32b97837.mbti`
/// -- see `PROVENANCE.md` for exactly how they were obtained), embedded here
/// as string literals byte-for-byte identical to those two files, the same
/// way `src/ingest/core_corpus_wbtest.mbt` embeds its 79-file corpus. Needed
/// because this package's test still has to hand `of_mbti_source` a `String`,
/// and nothing in this project has (or needs) a runtime file-read API yet --
/// `src/cmd/mbti-compat` reading real files from real paths is explicitly a
/// later milestone (M1 step 7). If either vendored file ever changes, these
/// two literals must be regenerated from it, never hand-edited independently
/// -- a mismatch between the two would silently test the wrong thing.
let old_source : String =
  "// Generated using `moon info`, DON'T EDIT IT\npackage \"moonbitlang/core/argparse\"\n\nimport {\n  \"moonbitlang/core/debug\",\n}\n\n// Values\n\n// Errors\n\n// Types and methods\npub struct ArgGroup {\n  // private fields\n} derive(@debug.Debug)\n#alias(new, deprecated)\npub fn ArgGroup::ArgGroup(StringView, required? : Bool, multiple? : Bool, args? : ArrayView[String], requires? : ArrayView[String], conflicts_with? : ArrayView[String]) -> Self\n\npub struct Command {\n  // private fields\n} derive(@debug.Debug)\n#alias(new, deprecated)\npub fn Command::Command(StringView, flags? : ArrayView[FlagArg], options? : ArrayView[OptionArg], positionals? : ArrayView[PositionArg], subcommands? : ArrayView[Self], about? : StringView, version? : StringView, disable_help_flag? : Bool, disable_version_flag? : Bool, disable_help_subcommand? : Bool, arg_required_else_help? : Bool, subcommand_required? : Bool, hidden? : Bool, groups? : ArrayView[ArgGroup]) -> Self\n#as_free_fn\npub fn Command::parse(Self, argv? : ArrayView[String], env? : Map[String, String]) -> Matches raise\npub fn Command::render_help(Self) -> String\n\npub(all) enum FlagAction {\n  SetTrue\n  SetFalse\n  Count\n  Help\n  Version\n} derive(Eq, Show, @debug.Debug)\n\npub struct FlagArg {\n  // private fields\n} derive(@debug.Debug)\n#alias(new, deprecated)\npub fn FlagArg::FlagArg(StringView, short? : Char, long? : StringView, about? : StringView, action? : FlagAction, env? : StringView, requires? : ArrayView[String], conflicts_with? : ArrayView[String], required? : Bool, global? : Bool, negatable? : Bool, hidden? : Bool) -> Self\n\npub struct Matches {\n  flags : Map[String, Bool]\n  values : Map[String, Array[String]]\n  flag_counts : Map[String, Int]\n  sources : Map[String, ValueSource]\n  subcommand : (String, Matches)?\n  // private fields\n} derive(@debug.Debug)\n\npub(all) enum OptionAction {\n  Set\n  Append\n} derive(Eq, Show, @debug.Debug)\n\npub struct OptionArg {\n  // private fields\n} derive(@debug.Debug)\n#alias(new, deprecated)\npub fn OptionArg::OptionArg(StringView, short? : Char, long? : StringView, about? : StringView, action? : OptionAction, env? : StringView, default_values? : ArrayView[String], allow_hyphen_values? : Bool, requires? : ArrayView[String], conflicts_with? : ArrayView[String], required? : Bool, global? : Bool, hidden? : Bool) -> Self\n\npub struct PositionArg {\n  // private fields\n} derive(@debug.Debug)\n#alias(new, deprecated)\npub fn PositionArg::PositionArg(StringView, about? : StringView, env? : StringView, default_values? : ArrayView[String], num_args? : ValueRange, allow_hyphen_values? : Bool, requires? : ArrayView[String], conflicts_with? : ArrayView[String], global? : Bool, hidden? : Bool) -> Self\n\npub struct ValueRange {\n  // private fields\n} derive(Eq, Show, @debug.Debug)\n#alias(new, deprecated)\npub fn ValueRange::ValueRange(lower? : Int, upper? : Int) -> Self\npub fn ValueRange::single() -> Self\n\npub enum ValueSource {\n  Argv\n  Env\n  Default\n} derive(Eq, Show, @debug.Debug)\n\n// Type aliases\n\n// Traits\n\n"

let new_source : String =
  "// Generated using `moon info`, DON'T EDIT IT\npackage \"moonbitlang/core/argparse\"\n\nimport {\n  \"moonbitlang/core/debug\",\n}\n\n// Values\n\n// Errors\n\n// Types and methods\ntype ArgGroup derive(@debug.Debug)\n#alias(new, deprecated)\npub fn ArgGroup::ArgGroup(StringView, required? : Bool, multiple? : Bool, args? : ArrayView[String], requires? : ArrayView[String], conflicts_with? : ArrayView[String]) -> Self\n\npub struct Command {\n  // private fields\n} derive(@debug.Debug)\n#alias(new, deprecated)\npub fn Command::Command(StringView, flags? : ArrayView[FlagArg], options? : ArrayView[OptionArg], positionals? : ArrayView[PositionArg], subcommands? : ArrayView[Self], about? : StringView, version? : StringView, disable_help_flag? : Bool, disable_version_flag? : Bool, disable_help_subcommand? : Bool, arg_required_else_help? : Bool, subcommand_required? : Bool, hidden? : Bool, groups? : ArrayView[ArgGroup], default_subcommand? : StringView) -> Self\n#as_free_fn\npub fn Command::parse(Self, argv? : ArrayView[String], env? : Map[String, String]) -> Matches raise\npub fn Command::render_help(Self) -> String\n\npub(all) enum FlagAction {\n  SetTrue\n  SetFalse\n  Count\n  Help\n  Version\n} derive(Eq, @debug.Debug)\npub fn FlagAction::equal(Self, Self) -> Bool\npub fn FlagAction::to_string(Self) -> String\n\npub struct FlagArg {\n  // private fields\n} derive(@debug.Debug)\n#alias(new, deprecated)\npub fn FlagArg::FlagArg(StringView, short? : Char, long? : StringView, about? : StringView, action? : FlagAction, env? : StringView, requires? : ArrayView[String], conflicts_with? : ArrayView[String], required? : Bool, global? : Bool, negatable? : Bool, hidden? : Bool) -> Self\n\npub struct Matches {\n  flags : Map[String, Bool]\n  values : Map[String, Array[String]]\n  flag_counts : Map[String, Int]\n  sources : Map[String, ValueSource]\n  subcommand : (String, Matches)?\n  // private fields\n} derive(@debug.Debug)\n\npub(all) enum OptionAction {\n  Set\n  Append\n} derive(Eq, @debug.Debug)\npub fn OptionAction::equal(Self, Self) -> Bool\npub fn OptionAction::to_string(Self) -> String\n\npub struct OptionArg {\n  // private fields\n} derive(@debug.Debug)\n#alias(new, deprecated)\npub fn OptionArg::OptionArg(StringView, short? : Char, long? : StringView, about? : StringView, action? : OptionAction, env? : StringView, default_values? : ArrayView[String], allow_hyphen_values? : Bool, requires? : ArrayView[String], conflicts_with? : ArrayView[String], required? : Bool, global? : Bool, hidden? : Bool) -> Self\n\npub struct PositionArg {\n  // private fields\n} derive(@debug.Debug)\n#alias(new, deprecated)\npub fn PositionArg::PositionArg(StringView, about? : StringView, env? : StringView, default_values? : ArrayView[String], num_args? : ValueRange, allow_hyphen_values? : Bool, requires? : ArrayView[String], conflicts_with? : ArrayView[String], global? : Bool, hidden? : Bool) -> Self\n\npub struct ValueRange {\n  // private fields\n} derive(Eq, Show, @debug.Debug)\n#alias(new, deprecated)\npub fn ValueRange::ValueRange(lower? : Int, upper? : Int) -> Self\npub fn ValueRange::equal(Self, Self) -> Bool\npub fn ValueRange::single() -> Self\npub fn ValueRange::to_string(Self) -> String\n\npub enum ValueSource {\n  Argv\n  Env\n  Default\n} derive(Eq, Show, @debug.Debug)\npub fn ValueSource::equal(Self, Self) -> Bool\npub fn ValueSource::to_string(Self) -> String\n\n// Type aliases\n\n// Traits\n"

///| Reproduces Gate 2's recorded findings for this exact pair of snapshots
/// (see the design brief's "First demonstration (M1, useful alone)" section
/// and `gate3-decisions-and-plan.md`'s step 6): `ingest`+`compare` alone,
/// with no `report`/`cmd` layer yet, already separates one real break from
/// the noise a plain text diff would show.
///
/// Every specific finding Gate 2 named is asserted individually below (via
/// `expected`, a plain `(symbol, rule, level)` table walked with `.each`,
/// deliberately avoiding any named helper function or typed-lambda-in-`let`
/// this project hasn't already proven compiles), plus one finding Gate 2's
/// brief didn't call out by name but the real data does contain
/// (`OptionAction` losing `derive(Show)` exactly the same way `FlagAction`
/// does) -- recorded honestly rather than only asserting the illustrative
/// subset, since this is real upstream history, not a curated fixture.
/// Failure messages deliberately don't print `Level` values (only
/// `Debug`-derived, never yet interpolated via `\{}` anywhere in this
/// project) -- the symbol and rule id already pinpoint which expectation
/// failed.
test "core-drift: reproduces Gate 2's recorded argparse findings" {
  let failures : Array[String] = []
  try {
    let old_surface = @ingest.of_mbti_source(old_source, name="moonbitlang/core/argparse")
    let new_surface = @ingest.of_mbti_source(new_source, name="moonbitlang/core/argparse")
    let delta = @compare.compare(old=old_surface, new=new_surface)
    let expected : Array[(String, String, @compare.Level)] = [
      ("ArgGroup", "opacity-unchanged", @compare.Level::Patch),
      ("Command::Command", "func-param-optional-added", @compare.Level::Minor),
      ("FlagAction", "derive-removed", @compare.Level::Major),
      ("OptionAction", "derive-removed", @compare.Level::Major),
      ("FlagAction::equal", "sym-added", @compare.Level::Minor),
      ("FlagAction::to_string", "sym-added", @compare.Level::Minor),
      ("OptionAction::equal", "sym-added", @compare.Level::Minor),
      ("OptionAction::to_string", "sym-added", @compare.Level::Minor),
      ("ValueRange::equal", "sym-added", @compare.Level::Minor),
      ("ValueRange::to_string", "sym-added", @compare.Level::Minor),
      ("ValueSource::equal", "sym-added", @compare.Level::Minor),
      ("ValueSource::to_string", "sym-added", @compare.Level::Minor),
    ]
    expected.each(fn(entry) {
      let (symbol, rule, level) = entry
      let matches = delta.changes.filter(fn(c) { c.symbol.0 == symbol && c.rule.0 == rule })
      if matches.length() == 0 {
        failures.push("expected \{symbol} \{rule}, found nothing")
      } else if matches[0].level != level {
        failures.push("\{symbol} \{rule} has the wrong level")
      }
    })

    // The overall verdict this delta requires is MAJOR, driven by the two
    // `derive-removed` changes -- exactly the number Gate 2's checklist
    // wants a reader to notice underneath the larger MINOR/PATCH noise.
    if delta.level() != @compare.Level::Major {
      failures.push("expected the overall delta level to be Major")
    }

    // No other changes should have been found beyond the 12 expected above
    // (1 opacity-unchanged + 1 func-param-optional-added + 2 derive-removed +
    // 8 sym-added) -- a stricter check than the per-entry loop above on its
    // own, catching anything unexpected the two real files also happen to
    // differ on.
    if delta.changes.length() != expected.length() {
      let details = delta.changes
        .map(fn(c) { "\{c.symbol.0} \{c.rule.0}" })
        .join("; ")
      failures.push(
        "expected exactly \{expected.length()} changes total, got \{delta.changes.length()}: \{details}",
      )
    }
  } catch {
    _ => failures.push("failed to parse a vendored real .mbti snapshot")
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}
