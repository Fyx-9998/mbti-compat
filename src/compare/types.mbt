///| How large a version bump a change requires. `Patch` doubles as the "no
/// bump needed" floor -- an empty `Delta` (nothing changed at all) reports
/// `Patch`, not a fourth "none" case, matching Gate 2's three-variant sketch.
pub(all) enum Level {
  Patch
  Minor
  Major
} derive(Eq, Compare, Debug)

///| A stable identifier for one classification rule, e.g.
/// `RuleId("func-param-removed")`. Kept as its own type rather than a bare
/// `String` so a `Change`'s `rule` field and `explain`'s argument can't be
/// confused with an arbitrary display string.
pub(all) struct RuleId(String) derive(Eq, Debug)

///| A reserved `SymbolId` spelling for changes that describe an entire
/// package rather than one symbol (`import-list-changed`, and a whole
/// package appearing/disappearing under `compare_module`). No real `.mbti`
/// symbol ever produces this exact string: `ingest` only ever derives ids
/// from real identifier text (`Name.name`, optionally rendered as
/// `"Owner::name"`), which never contains angle brackets.
pub let package_level_symbol : SymbolId = SymbolId("<package>")

///| One classified difference between an old and a new `Surface`. `symbol`
/// is always present, even for a package-wide fact -- see
/// `package_level_symbol` above.
///
/// `old_span`/`new_span` are `None` far more often than not in this M1:
/// today only `Symbol::Unsupported` carries a source span in the `surface`
/// model, so every rule *except* `unsupported-changed` reports `None` for
/// both. Documented scope gap, not silently hidden -- revisit by threading
/// spans through every shape in a future milestone if precise
/// point-to-the-line reporting turns out to matter enough to justify it.
pub(all) struct Change {
  level : Level
  rule : RuleId
  package_name : String
  symbol : SymbolId
  detail : String
  old_span : Span?
  new_span : Span?
  waived : Bool
} derive(Eq, Debug)

///| The full set of differences between two `Surface`s (or two whole
/// modules via `compare_module`), sorted deterministically by
/// `(package_name, symbol, rule)` so two runs over identical inputs always
/// produce identical output -- required for the golden-snapshot test in
/// Gate 2's evaluator checklist.
pub(all) struct Delta {
  changes : Array[Change]
} derive(Eq, Debug)

///| The version bump this delta requires: the highest `Level` among its
/// non-waived changes, or `Patch` if there are none. A change with
/// `waived: true` (set by `policy::Delta::apply`, never by `compare` itself)
/// never contributes to the required bump -- that is the entire point of a
/// waiver -- but it is never removed from `changes` either, matching Gate
/// 2's correctness requirement that waivers mark, not delete.
pub fn Delta::level(self : Delta) -> Level {
  let mut level = Patch
  self.changes.each(fn(c) {
    if !(c.waived) && c.level > level {
      level = c.level
    }
  })
  level
}

///| Changes at or above this level, ignoring waived ones -- the array a
/// report renderer actually wants to walk to explain *why* `Delta::level`
/// came out the way it did.
pub fn Delta::active_changes(self : Delta) -> Array[Change] {
  self.changes.filter(fn(c) { !(c.waived) })
}
