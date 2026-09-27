///| Single shared `using` block for `src/policy`, mirroring `compare`'s and
/// `report`'s own `imports.mbt` convention (see those files' doc comments).
/// Brings `compare`'s `Delta`/`Level` into unprefixed scope so
/// `required_version`/`verdict`'s signatures match Gate 2's design brief
/// exactly (`Delta`, not `@compare.Delta`) and so `required_version` can
/// pattern-match on `Level`'s three variants directly.
using @compare {
  type Delta,
  type Level,
}
