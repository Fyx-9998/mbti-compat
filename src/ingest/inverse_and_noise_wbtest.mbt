///| The two correctness properties deliberately deferred from the corpus
/// round (see the project doc): unlike the corpus test, these don't need any
/// real upstream text -- only tiny hand-crafted `.mbti` fixtures, parsed and
/// compared with the exact same already-proven `of_mbti_source`/
/// `@compare.compare` calls the corpus test already exercises. Kept in their
/// own file, separate from `properties_wbtest.mbt`, since they test a
/// different thing (compare's own symmetry/order-insensitivity, not
/// ingest's coverage of real-world syntax).
///
/// Failures are collected into an array and `fail`-ed once at the end of
/// each test, rather than calling `fail` directly inside the `try` block --
/// a `fail` call inside a `try` would otherwise be swallowed by that same
/// try's own `catch` and reported as a generic parse failure instead of the
/// real assertion message.

///| Inverse consistency, case 1: an added/removed symbol must swap both rule
/// id (`sym-removed` <-> `sym-added`) and level (`Major` <-> `Minor`)
/// symmetrically when the comparison direction is reversed.
test "inverse consistency: add/remove swaps rule and level symmetrically" {
  let failures : Array[String] = []
  try {
    let with_foo = of_mbti_source(
      "package \"test/inverse1\"\n\npub fn foo() -> Unit\n",
      name="inverse1",
    )
    let without_foo = of_mbti_source("package \"test/inverse1\"\n", name="inverse1")
    let removed = @compare.compare(old=with_foo, new=without_foo)
    let added = @compare.compare(old=without_foo, new=with_foo)
    if removed.changes.length() != 1 {
      failures.push(
        "expected exactly one change for a removed symbol, got \{removed.changes.length()}",
      )
    } else if added.changes.length() != 1 {
      failures.push(
        "expected exactly one change for an added symbol, got \{added.changes.length()}",
      )
    } else {
      let removed_change = removed.changes[0]
      let added_change = added.changes[0]
      if removed_change.rule.0 != "sym-removed" {
        failures.push("expected rule 'sym-removed', got '\{removed_change.rule.0}'")
      }
      if added_change.rule.0 != "sym-added" {
        failures.push("expected rule 'sym-added', got '\{added_change.rule.0}'")
      }
      if removed_change.level != @compare.Level::Major {
        failures.push("expected a removed symbol to classify as Major")
      }
      if added_change.level != @compare.Level::Minor {
        failures.push("expected an added symbol to classify as Minor")
      }
    }
  } catch {
    _ => failures.push("failed to parse a hand-crafted inverse-consistency fixture (add/remove)")
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}

///| Inverse consistency, case 2: a same-symbol payload change (here, a
/// changed return type) must report the *same* rule id and level regardless
/// of which side is called "old" and which is "new" -- neither direction is
/// privileged the way add/remove are.
test "inverse consistency: a payload change reports the same rule and level either way" {
  let failures : Array[String] = []
  try {
    let returns_int = of_mbti_source(
      "package \"test/inverse2\"\n\npub fn bar() -> Int\n",
      name="inverse2",
    )
    let returns_string = of_mbti_source(
      "package \"test/inverse2\"\n\npub fn bar() -> String\n",
      name="inverse2",
    )
    let forward = @compare.compare(old=returns_int, new=returns_string)
    let backward = @compare.compare(old=returns_string, new=returns_int)
    if forward.changes.length() != 1 {
      failures.push(
        "expected exactly one change going forward, got \{forward.changes.length()}",
      )
    } else if backward.changes.length() != 1 {
      failures.push(
        "expected exactly one change going backward, got \{backward.changes.length()}",
      )
    } else {
      let forward_change = forward.changes[0]
      let backward_change = backward.changes[0]
      if forward_change.rule.0 != backward_change.rule.0 {
        failures.push(
          "expected the same rule id in both directions, got '\{forward_change.rule.0}' vs '\{backward_change.rule.0}'",
        )
      }
      if forward_change.level != backward_change.level {
        failures.push("expected the same level in both directions")
      }
      if forward_change.level != @compare.Level::Major {
        failures.push("expected a changed return type to classify as Major")
      }
    }
  } catch {
    _ => failures.push("failed to parse a hand-crafted inverse-consistency fixture (payload change)")
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}

///| Noise immunity: reordering declarations, adding comments, and varying
/// blank-line whitespace must not change `compare`'s output at all.
/// `ingest` converts into a `Map` keyed by `SymbolId`, so declaration order
/// in the source text never survives into `Surface`, and comments/blank
/// lines aren't part of `.mbti`'s grammar in the first place.
test "noise immunity: reordering, comments, and whitespace produce zero changes" {
  let failures : Array[String] = []
  try {
    let tidy = of_mbti_source(
      "package \"test/noise\"\n\npub fn foo() -> Unit\n\npub fn bar(Int) -> Int\n",
      name="noise",
    )
    let noisy = of_mbti_source(
      "package \"test/noise\"\n\n\n// bar is declared first here, and foo second --\n// pure reordering plus comments and extra blank lines.\npub fn bar(Int) -> Int\n\n\n\npub fn foo() -> Unit\n",
      name="noise",
    )
    let delta = @compare.compare(old=tidy, new=noisy)
    if delta.changes.length() != 0 {
      let details = delta.changes.map(fn(c) { "\{c.rule.0}: \{c.detail}" }).join("; ")
      failures.push(
        "expected zero changes across a reorder+comment+whitespace variant, got \{delta.changes.length()} (\{details})",
      )
    }
  } catch {
    _ => failures.push("failed to parse a hand-crafted noise-immunity fixture")
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}
