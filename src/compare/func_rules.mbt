///| `Optional`'s `default~` string never affects compatibility (Gate 2: exact
/// default *values* don't matter, only whether a parameter is optional at
/// all) -- normalize it away before comparing two `Optional` parameters so a
/// changed default doesn't get mistaken for a changed signature.
fn normalize_param(p : Parameter) -> Parameter {
  match p {
    Optional(name~, ty~, default=_) => Optional(name~, ty~, default="")
    other => other
  }
}

///| Whether `p` is one of the two "optional" parameter kinds -- the only
/// kinds that can be added at the end of a parameter list without breaking
/// existing callers.
fn is_optional_param(p : Parameter) -> Bool {
  match p {
    Optional(..) => true
    QuestionOptional(..) => true
    _ => false
  }
}

///| Compare two parameter lists. Deliberately simple and positional (no
/// attempt to detect a reordered-but-otherwise-identical labelled parameter
/// as a no-op): good enough for M1, and conservative in the safe direction
/// -- a real reorder will be reported as a change rather than missed.
fn diff_params(old : Array[Parameter], new : Array[Parameter]) -> Array[Reason] {
  let old_len = old.length()
  let new_len = new.length()
  if new_len < old_len {
    return [
      (
        RuleId("func-param-removed"),
        Major,
        "parameter count decreased from \{old_len} to \{new_len}",
      ),
    ]
  }
  if new_len > old_len {
    // Common prefix must be untouched, and every added parameter must be
    // optional, for this to be the safe "trailing optional added" case.
    let mut prefix_unchanged = true
    let mut i = 0
    while i < old_len {
      if normalize_param(old[i]) != normalize_param(new[i]) {
        prefix_unchanged = false
      }
      i = i + 1
    }
    let mut all_added_optional = true
    let mut j = old_len
    while j < new_len {
      if !(is_optional_param(new[j])) {
        all_added_optional = false
      }
      j = j + 1
    }
    if prefix_unchanged && all_added_optional {
      return [
        (
          RuleId("func-param-optional-added"),
          Minor,
          "\{new_len - old_len} trailing optional parameter(s) added",
        ),
      ]
    }
    if prefix_unchanged {
      return [
        (
          RuleId("func-param-required-added"),
          Major,
          "\{new_len - old_len} trailing required parameter(s) added",
        ),
      ]
    }
    // Prefix itself changed as well as the length -- fall through to the
    // equal-length-style pairwise report below, over the common prefix,
    // plus a note about the length change.
    let reasons = diff_params_pairwise(old, new, old_len)
    reasons.push(
      (
        RuleId("func-param-required-added"),
        Major,
        "parameter count increased from \{old_len} to \{new_len}",
      ),
    )
    return reasons
  }
  diff_params_pairwise(old, new, old_len)
}

///| Pairwise-compare the first `count` parameters of `old` and `new` (both
/// guaranteed at least `count` long by the caller).
fn diff_params_pairwise(
  old : Array[Parameter],
  new : Array[Parameter],
  count : Int,
) -> Array[Reason] {
  let reasons : Array[Reason] = []
  let mut i = 0
  while i < count {
    if normalize_param(old[i]) != normalize_param(new[i]) {
      reasons.push(
        (
          RuleId("func-param-type-changed"),
          Major,
          "parameter at position \{i} changed",
        ),
      )
    }
    i = i + 1
  }
  reasons
}

///| Rank an `ErrorAnnotation` by whether calling code needs to account for a
/// raised error at all: `0` if it provably can't raise, `1` otherwise.
/// `MaybeError` (`raise?`, conditional on the caller's own context) is
/// ranked `1` -- conservative, since some calling contexts do need to
/// handle it.
fn raise_rank(e : ErrorAnnotation) -> Int {
  match e {
    NoErrorType => 0
    Noraise => 0
    DefaultErrorType => 1
    RaisesType(..) => 1
    MaybeError(..) => 1
  }
}

fn diff_error_annotation(old : ErrorAnnotation, new : ErrorAnnotation) -> Array[Reason] {
  let old_rank = raise_rank(old)
  let new_rank = raise_rank(new)
  if old_rank == 0 && new_rank == 1 {
    [(RuleId("func-raise-added"), Major, "gained the ability to raise an error")]
  } else if old_rank == 1 && new_rank == 0 {
    [
      (
        RuleId("func-raise-removed"),
        Minor,
        "can no longer raise an error (callers with a surrounding try/catch may stop compiling)",
      ),
    ]
  } else if old_rank == 1 && new_rank == 1 && old != new {
    [(RuleId("func-raise-type-changed"), Major, "raised error type changed")]
  } else {
    []
  }
}

///| The full set of reasons two function-like signatures differ: generics
/// arity/content, parameters, return type, raise behavior, and async-ness.
/// Shared verbatim between free functions/methods (`diff_func`, where each
/// reason becomes its own `Change`) and trait methods (`diff_trait`, where
/// the whole array is collapsed into a single `trait-method-signature-changed`
/// `Change` regardless of how many individual reasons fired -- see
/// `symbol_rules.mbt` for why).
fn func_signature_diff_reasons(
  old_generics : Array[String],
  old_params : Array[Parameter],
  old_return : String,
  old_error : ErrorAnnotation,
  old_async : Bool,
  new_generics : Array[String],
  new_params : Array[Parameter],
  new_return : String,
  new_error : ErrorAnnotation,
  new_async : Bool,
) -> Array[Reason] {
  let reasons : Array[Reason] = []
  diff_generics(old_generics, new_generics).each(fn(r) { reasons.push(r) })
  diff_params(old_params, new_params).each(fn(r) { reasons.push(r) })
  if old_return != new_return {
    reasons.push(
      (RuleId("func-return-narrowed"), Major, "return type changed from \{old_return} to \{new_return}"),
    )
  }
  diff_error_annotation(old_error, new_error).each(fn(r) { reasons.push(r) })
  if old_async != new_async {
    reasons.push((RuleId("async-changed"), Major, "async-ness changed"))
  }
  reasons
}

///| Compare two `FuncShape`s that share a `SymbolId` (so `method_of` is
/// guaranteed identical already -- it's baked into the id itself, see
/// `ingest.mbt`'s `convert_func`). Each reason becomes its own `Change`.
fn diff_func(old : FuncShape, new : FuncShape) -> Array[Reason] {
  func_signature_diff_reasons(
    old.generics,
    old.params,
    old.return_type,
    old.error_annotation,
    old.is_async,
    new.generics,
    new.params,
    new.return_type,
    new.error_annotation,
    new.is_async,
  )
}
