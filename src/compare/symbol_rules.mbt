///| Order-insensitive equality for two string lists treated as sets (used
/// for a trait's supertrait list, where declaration order isn't meaningful).
fn string_sets_equal(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let set_b = index_by_name(b, fn(s : String) { s })
  let mut all_present = true
  a.each(fn(s) { if !(set_b.contains(s)) { all_present = false } })
  all_present
}

///| Compare two `TraitMethodShape`s (same method name, different trait
/// versions) for *any* signature difference, folding `has_default` into the
/// comparison too. Returns the underlying reasons (unused individually --
/// `diff_trait` collapses them into one `Change`) purely so the detail text
/// can summarize what changed.
fn trait_method_diff_reasons(old : TraitMethodShape, new : TraitMethodShape) -> Array[Reason] {
  let reasons = func_signature_diff_reasons(
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
  if old.has_default != new.has_default {
    reasons.push((RuleId("trait-method-signature-changed"), Major, "default-ness changed"))
  }
  reasons
}

///| Compare two `TraitShape`s that share a `SymbolId`. Every *existing*
/// method whose signature differs at all collapses into one MAJOR
/// `trait-method-signature-changed` `Change` -- unlike a free function,
/// where e.g. adding a raise is only MINOR, a trait method's signature must
/// match exactly for every implementor, so any drift at all is breaking,
/// full stop.
fn diff_trait(old : TraitShape, new : TraitShape) -> Array[Reason] {
  let reasons : Array[Reason] = []
  diff_visibility(old.visibility, new.visibility).each(fn(r) { reasons.push(r) })
  if !(string_sets_equal(old.supertraits, new.supertraits)) {
    reasons.push(
      (RuleId("trait-supertraits-changed"), Major, "supertrait list changed"),
    )
  }
  let old_by_name = index_by_name(old.methods, fn(m : TraitMethodShape) { m.name })
  let new_by_name = index_by_name(new.methods, fn(m : TraitMethodShape) { m.name })
  old_by_name.keys().each(fn(name) {
    if !(new_by_name.contains(name)) {
      reasons.push((RuleId("trait-method-removed"), Major, "method \{name} removed"))
    }
  })
  new_by_name.keys().each(fn(name) {
    if !(old_by_name.contains(name)) {
      let m = new_by_name.get(name).unwrap()
      if m.has_default {
        reasons.push(
          (RuleId("trait-method-added-with-default"), Minor, "method \{name} added, with a default implementation"),
        )
      } else {
        reasons.push(
          (RuleId("trait-method-added-no-default"), Major, "method \{name} added, with no default implementation"),
        )
      }
    }
  })
  old_by_name.keys().each(fn(name) {
    match new_by_name.get(name) {
      None => ()
      Some(nm) => {
        let om = old_by_name.get(name).unwrap()
        let method_reasons = trait_method_diff_reasons(om, nm)
        if !(method_reasons.is_empty()) {
          let details = method_reasons.map(fn(r) { r.2 }).join("; ")
          reasons.push(
            (RuleId("trait-method-signature-changed"), Major, "method \{name} signature changed: \{details}"),
          )
        }
      }
    }
  })
  reasons
}

///| Compare two `ImplShape`s that share a `SymbolId`. `trait_name` and
/// `type_name` can never actually differ here: `ingest.mbt`'s
/// `convert_impl` bakes both into the id itself
/// (`"impl \{trait_name} for \{type_name}"`), so if either changed, this
/// would be a different id entirely -- handled as a `sym-removed` +
/// `sym-added` (specialized to `impl-removed`/`impl-added`) pair by
/// `diff_symbol`, never as a same-id modification. Only `generics` can
/// legitimately differ here.
fn diff_impl(old : ImplShape, new : ImplShape) -> Array[Reason] {
  diff_generics(old.generics, new.generics)
}

fn diff_const(old : ConstShape, new : ConstShape) -> Array[Reason] {
  if old.ty != new.ty {
    [(RuleId("const-type-changed"), Major, "type changed from \{old.ty} to \{new.ty}")]
  } else if old.value != new.value {
    [(RuleId("const-value-changed"), Patch, "value changed")]
  } else {
    []
  }
}

fn diff_value(old : ValueShape, new : ValueShape) -> Array[Reason] {
  if old.ty != new.ty {
    [(RuleId("value-type-changed"), Major, "type changed from \{old.ty} to \{new.ty}")]
  } else {
    []
  }
}

fn diff_alias(old : AliasShape, new : AliasShape) -> Array[Reason] {
  match (old, new) {
    (TypeAliasShape(target=ot, visibility=ov, generics=og), TypeAliasShape(target=nt, visibility=nv, generics=ng)) => {
      let reasons : Array[Reason] = []
      if ot != nt {
        reasons.push(
          (RuleId("alias-target-changed"), Major, "alias target changed from \{ot} to \{nt}"),
        )
      }
      diff_visibility(ov, nv).each(fn(r) { reasons.push(r) })
      diff_generics(og, ng).each(fn(r) { reasons.push(r) })
      reasons
    }
    (UsingShape(pkg=op, target=ot, local_name=ol), UsingShape(pkg=np, target=nt, local_name=nl)) =>
      if op != np || ot != nt || ol != nl {
        [(RuleId("alias-target-changed"), Major, "using-re-export target changed")]
      } else {
        []
      }
    (FuncAliasShape(type_name=ot), FuncAliasShape(type_name=nt)) =>
      if ot != nt {
        [(RuleId("alias-target-changed"), Major, "free-function alias target changed from \{ot} to \{nt}")]
      } else {
        []
      }
    _ => [(RuleId("alias-target-changed"), Major, "alias mechanism changed entirely")]
  }
}

///| Whether a `Symbol::Alias` is the `#as_free_fn` mechanism specifically --
/// used by `diff_symbol` to give an added/removed free-function alias the
/// more specific `as-free-fn-added`/`as-free-fn-removed` rule id instead of
/// the generic `sym-added`/`sym-removed`.
fn is_free_fn_alias(sym : Symbol) -> Bool {
  match sym {
    Alias(FuncAliasShape(..)) => true
    _ => false
  }
}

fn is_impl_symbol(sym : Symbol) -> Bool {
  match sym {
    Impl(_) => true
    _ => false
  }
}

fn is_unsupported(sym : Symbol) -> Bool {
  match sym {
    Unsupported(..) => true
    _ => false
  }
}

///| Compare two `Symbol`s known to share a `SymbolId` and to already be
/// unequal (`compare.mbt`'s caller fast-paths the equal case away). `raw`
/// text changing on either side (or a symbol switching in or out of
/// `Unsupported` entirely) is always conservatively `unsupported-changed`,
/// checked before the ordinary per-kind dispatch below; a fallback there
/// covers the (rare, likely-impossible in practice) case where a resolved
/// symbol's kind changed outright under a stable id.
fn diff_symbol_payload(old : Symbol, new : Symbol) -> Array[Reason] {
  if is_unsupported(old) || is_unsupported(new) {
    match (old, new) {
      (Unsupported(raw=oraw, ..), Unsupported(raw=nraw, ..)) =>
        if oraw == nraw {
          []
        } else {
          [(RuleId("unsupported-changed"), Major, "unmodelled declaration text changed")]
        }
      _ =>
        [
          (
            RuleId("unsupported-changed"),
            Major,
            "became (or stopped being) an unmodelled declaration",
          ),
        ]
    }
  } else {
    match (old, new) {
      (Func(of), Func(nf)) => diff_func(of, nf)
      (Type(ot), Type(nt)) => diff_type(ot, nt)
      (Trait(ot), Trait(nt)) => diff_trait(ot, nt)
      (Impl(oi), Impl(ni)) => diff_impl(oi, ni)
      (Const(oc), Const(nc)) => diff_const(oc, nc)
      (Value(ov), Value(nv)) => diff_value(ov, nv)
      (Alias(oa), Alias(na)) => diff_alias(oa, na)
      _ => [(RuleId("sym-kind-changed"), Major, "symbol's kind changed")]
    }
  }
}
