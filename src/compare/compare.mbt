///| Diff exactly one symbol id between an old and new package, given as
/// `Option`s so the same function handles "removed" (`new` is `None`),
/// "added" (`old` is `None`), and "present in both" uniformly. `impl` and
/// `#as_free_fn`-alias symbols get their own, more specific rule ids on
/// add/remove (Gate 2 names these separately from the generic
/// `sym-added`/`sym-removed`) even though the *level* is the same either
/// way.
fn diff_symbol(
  id : SymbolId,
  package_name : String,
  old : Symbol?,
  new : Symbol?,
) -> Array[Change] {
  match (old, new) {
    (None, None) => []
    (Some(o), None) => {
      let (rule, detail) = if is_impl_symbol(o) {
        (RuleId("impl-removed"), "trait implementation removed")
      } else if is_free_fn_alias(o) {
        (RuleId("as-free-fn-removed"), "free-function alias removed")
      } else {
        (RuleId("sym-removed"), "symbol removed")
      }
      [anchor((rule, Major, detail), package_name~, symbol=id)]
    }
    (None, Some(n)) => {
      let (rule, detail) = if is_impl_symbol(n) {
        (RuleId("impl-added"), "trait implementation added")
      } else if is_free_fn_alias(n) {
        (RuleId("as-free-fn-added"), "free-function alias added")
      } else {
        (RuleId("sym-added"), "symbol added")
      }
      [anchor((rule, Minor, detail), package_name~, symbol=id)]
    }
    (Some(o), Some(n)) =>
      if o == n {
        []
      } else {
        diff_symbol_payload(o, n).map(fn(r) { anchor(r, package_name~, symbol=id) })
      }
  }
}

///| A `Surface` standing in for a package that doesn't exist on one side of
/// a `compare_module` comparison -- so a whole added/removed package is
/// reported the same informative way as any other symbol-by-symbol diff
/// (every one of its symbols shows up as `sym-added`/`sym-removed`, and its
/// import list shows up as `import-list-changed`), rather than as one vague
/// package-level marker.
fn empty_surface(name : String) -> Surface {
  Surface::{ package_name: name, imports: [], symbols: Map([]) }
}

///| The full set of differences between one package's old and new
/// `Surface`. Imports are compared once, up front, as a single PATCH-level
/// fact (Gate 2: not part of symbol-by-symbol classification); every symbol
/// present in either side is then compared exactly once via `diff_symbol`.
/// Sorted deterministically by `(package_name, symbol, rule)` before
/// returning.
pub fn compare(old~ : Surface, new~ : Surface) -> Delta {
  let changes : Array[Change] = []
  if old.imports != new.imports {
    changes.push(
      anchor(
        (RuleId("import-list-changed"), Patch, "import list changed"),
        package_name=new.package_name,
        symbol=package_level_symbol,
      ),
    )
  }
  old.symbols.each(fn(id, sym) {
    diff_symbol(id, new.package_name, Some(sym), new.symbols.get(id)).each(fn(c) {
      changes.push(c)
    })
  })
  new.symbols.each(fn(id, sym) {
    if !(old.symbols.contains(id)) {
      diff_symbol(id, new.package_name, None, Some(sym)).each(fn(c) { changes.push(c) })
    }
  })
  changes.sort_by_key(fn(c) { (c.package_name, c.symbol.0, c.rule.0) })
  Delta::{ changes }
}

///| The whole-module analogue of `compare`: every package present in either
/// `old` or `new` is compared (a package missing from one side is treated
/// as an empty `Surface` on that side, via `empty_surface`, so its removal
/// or addition is reported symbol-by-symbol rather than as one opaque
/// marker), and the results are merged into one deterministically sorted
/// `Delta`.
pub fn compare_module(
  old~ : Map[String, Surface],
  new~ : Map[String, Surface],
) -> Delta {
  let names : Map[String, Bool] = Map([])
  old.keys().each(fn(n) { names.set(n, true) })
  new.keys().each(fn(n) { names.set(n, true) })
  let changes : Array[Change] = []
  names.keys().each(fn(name) {
    let old_surface = match old.get(name) {
      Some(s) => s
      None => empty_surface(name)
    }
    let new_surface = match new.get(name) {
      Some(s) => s
      None => empty_surface(name)
    }
    compare(old=old_surface, new=new_surface).changes.each(fn(c) { changes.push(c) })
  })
  changes.sort_by_key(fn(c) { (c.package_name, c.symbol.0, c.rule.0) })
  Delta::{ changes }
}
