///| An internal, un-anchored classification result: a rule id, the level it
/// implies, and a human-readable detail string. `diff_*` helpers below
/// return arrays of these; `compare`/`diff_symbol` anchor them into real
/// `Change`s once a `SymbolId`, package name, and spans are known.
type Reason = (RuleId, Level, String)

///| Build a `Change` from a `Reason`, anchored to one symbol. `waived` always
/// starts `false` -- only `policy::Delta::apply` (a later milestone) ever
/// sets it `true`.
fn anchor(
  reason : Reason,
  package_name~ : String,
  symbol~ : SymbolId,
  old_span~ : Span? = None,
  new_span~ : Span? = None,
) -> Change {
  let (rule, level, detail) = reason
  Change::{ level, rule, package_name, symbol, detail, old_span, new_span, waived: false }
}

///| Compare two generic-parameter-name lists (used by funcs, trait methods,
/// types, aliases, and impls alike): arity change is MAJOR
/// `generic-arity-changed`; same arity but different content (a renamed or
/// re-constrained parameter) is MAJOR `generic-constraint-changed`, an
/// extension beyond Gate 2's exact table. Equal lists produce no `Reason`.
fn diff_generics(old : Array[String], new : Array[String]) -> Array[Reason] {
  if old.length() != new.length() {
    [
      (
        RuleId("generic-arity-changed"),
        Major,
        "generic parameter count changed from \{old.length()} to \{new.length()}",
      ),
    ]
  } else if old != new {
    [
      (
        RuleId("generic-constraint-changed"),
        Major,
        "generic parameters changed from [\{old.join(", ")}] to [\{new.join(", ")}]",
      ),
    ]
  } else {
    []
  }
}

///| A coarse, deliberately simplified rank for `Visibility`, used only to
/// decide *direction* (narrower vs. wider), not to model MoonBit's real
/// visibility rules exactly. `VisPriv` (shouldn't actually occur in a
/// `.mbti` file, which only ever lists the public interface, but is a real
/// case in the shared AST) ranks below everything. `VisDefault` and
/// `VisPub(attr=None)` rank equal: both leave a type externally
/// read-only/non-constructible (confirmed empirically in this very project
/// -- `pub struct SymbolId(String)` without `pub(all)` was read-only outside
/// its package), so a bare `pub` keyword appearing or disappearing where
/// the type was already unmarked-but-public isn't a real capability change.
/// `attr="open"` (trait external-implementability) and `attr="all"`
/// (external constructibility) apply to different declaration kinds and
/// aren't really comparable on one scale, but both strictly add a
/// capability the narrower forms lack, so both rank above the baseline,
/// with `"all"` ranked highest since it is the widest concrete capability
/// this model tracks.
fn visibility_rank(v : Visibility) -> Int {
  match v {
    VisPriv => 0
    VisDefault => 1
    VisPub(attr~) =>
      match attr {
        None => 1
        Some("open") => 2
        Some(_) => 3
      }
  }
}

///| MAJOR `vis-narrowed` if `new` is strictly less visible than `old`, MINOR
/// `vis-widened` if strictly more, nothing if the rank is unchanged (even if
/// the exact `Visibility` value differs, e.g. `VisDefault` vs.
/// `VisPub(attr=None)` -- see `visibility_rank`'s reasoning).
fn diff_visibility(old : Visibility, new : Visibility) -> Array[Reason] {
  let old_rank = visibility_rank(old)
  let new_rank = visibility_rank(new)
  if new_rank < old_rank {
    [(RuleId("vis-narrowed"), Major, "visibility became more restrictive")]
  } else if new_rank > old_rank {
    [(RuleId("vis-widened"), Minor, "visibility became less restrictive")]
  } else {
    []
  }
}

///| Index an array of shapes by name for set-style added/removed/changed
/// comparison (used for record fields, enum/variant constructors, and trait
/// methods -- everything in `surface` that has a `name` field but is stored
/// as a plain `Array`, not already keyed by identity the way `Surface`'s
/// top-level symbols are via `SymbolId`).
fn[T] index_by_name(items : Array[T], name_of : (T) -> String) -> Map[String, T] {
  let m : Map[String, T] = Map([])
  items.each(fn(it) { m.set(name_of(it), it) })
  m
}
