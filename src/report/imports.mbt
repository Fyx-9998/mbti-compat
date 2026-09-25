///| Single shared `using` block for the whole `report` package, mirroring
/// `compare`'s own `imports.mbt` (itself mirroring `moonbitlang/parser`'s
/// per-package convention -- see that file's own doc comment). Brings
/// `compare`'s public types into unprefixed scope so `render_text`/
/// `render_json`'s signatures can match Gate 2's design brief exactly
/// (`Delta`, not `@compare.Delta`), and lets `level_word` pattern-match on
/// `Level`'s three variants directly. Only the four types actually written
/// as bare annotations somewhere in this package are listed -- `RuleId` is
/// only ever reached via `change.rule.0` (field access needs no `using` at
/// all), so it's deliberately left out to avoid the same
/// `[0003] unused_type_declaration` cosmetic warning `properties_wbtest.mbt`
/// already has one instance of.
using @compare {
  type Delta,
  type Change,
  type Level,
}

///| Only `Span` is needed from `surface` -- `Change.old_span`/`new_span` are
/// `Span?`.
using @surface {
  type Span,
}
