///| Whether a `TypeDesc` presents no visible structure at all from outside
/// its defining package: either declared `Abstract`, or a `Record` whose
/// fields are *all* private. Gate 2's real example (`core/argparse`'s
/// `ArgGroup` switching between `pub struct ArgGroup { // private fields }`
/// and `type ArgGroup`) is exactly this second case -- both spellings are
/// equally opaque to a caller, so switching between them is `PATCH`
/// `opacity-unchanged`, not a real API change.
fn is_opaque_desc(desc : TypeDesc) -> Bool {
  match desc {
    Abstract => true
    Record(fields~) => fields.iter().all(fn(f) { f.visibility == VisPriv })
    _ => false
  }
}

///| Compare two `TypeDesc`s that belong to the same `TypeShape` (same
/// `SymbolId`, so already known not to be `==`). Dispatches first on
/// opacity (see `is_opaque_desc`), then on the specific pair of shapes.
fn diff_type_desc(old : TypeDesc, new : TypeDesc) -> Array[Reason] {
  let old_opaque = is_opaque_desc(old)
  let new_opaque = is_opaque_desc(new)
  if old_opaque && new_opaque {
    return [
      (RuleId("opacity-unchanged"), Patch, "type remained opaque across an equivalent spelling change"),
    ]
  }
  if !(old_opaque) && new_opaque {
    return [(RuleId("type-became-opaque"), Major, "type lost its previously visible structure")]
  }
  if old_opaque && !(new_opaque) {
    return [
      (RuleId("type-desc-widened"), Minor, "type gained visible structure it previously lacked"),
    ]
  }
  match (old, new) {
    (Record(fields=of), Record(fields=nf)) => diff_record_fields(of, nf)
    (Variant(constructors=oc), Variant(constructors=nc)) => diff_constructors(oc, nc, closed=true)
    (ExtensibleEnum(constructors=oc), ExtensibleEnum(constructors=nc)) =>
      diff_constructors(oc, nc, closed=false)
    (ExtendEnum(target=ot, constructors=oc), ExtendEnum(target=nt, constructors=nc)) => {
      let combined : Array[Reason] = []
      if ot != nt {
        combined.push(
          (RuleId("alias-target-changed"), Major, "extended enum's target changed from \{ot} to \{nt}"),
        )
      }
      diff_constructors(oc, nc, closed=false).each(fn(r) { combined.push(r) })
      combined
    }
    (ErrorDecl(payload=op), ErrorDecl(payload=np)) => diff_constructors(op, np, closed=true)
    (Newtype(target=ot), Newtype(target=nt)) =>
      if ot != nt {
        [(RuleId("newtype-target-changed"), Major, "wrapped type changed from \{ot} to \{nt}")]
      } else {
        []
      }
    (TupleStruct(components=oc), TupleStruct(components=nc)) =>
      if oc != nc {
        [
          (
            RuleId("tuple-struct-shape-changed"),
            Major,
            "positional component types changed from (\{oc.join(", ")}) to (\{nc.join(", ")})",
          ),
        ]
      } else {
        []
      }
    (AliasDesc(target=ot), AliasDesc(target=nt)) =>
      if ot != nt {
        [(RuleId("alias-target-changed"), Major, "alias target changed from \{ot} to \{nt}")]
      } else {
        []
      }
    _ =>
      [
        (
          RuleId("type-shape-kind-changed"),
          Major,
          "type declaration kind changed outright",
        ),
      ]
  }
}

///| Field-by-field diff of a `Record`'s fields, keyed by name.
fn diff_record_fields(old : Array[FieldShape], new : Array[FieldShape]) -> Array[Reason] {
  let old_by_name = index_by_name(old, fn(f : FieldShape) { f.name })
  let new_by_name = index_by_name(new, fn(f : FieldShape) { f.name })
  let reasons : Array[Reason] = []
  old_by_name.keys().each(fn(name) {
    if !(new_by_name.contains(name)) {
      reasons.push((RuleId("record-field-removed"), Major, "field \{name} removed"))
    }
  })
  new_by_name.keys().each(fn(name) {
    if !(old_by_name.contains(name)) {
      let f = new_by_name.get(name).unwrap()
      if f.visibility == VisPriv {
        reasons.push(
          (RuleId("record-field-added-opaque"), Minor, "private field \{name} added"),
        )
      } else {
        reasons.push(
          (RuleId("record-field-added-pub-all"), Major, "publicly visible field \{name} added"),
        )
      }
    }
  })
  old_by_name.keys().each(fn(name) {
    match new_by_name.get(name) {
      None => ()
      Some(nf) => {
        let of = old_by_name.get(name).unwrap()
        if of.ty != nf.ty || of.is_mutable != nf.is_mutable || of.visibility != nf.visibility {
          reasons.push((RuleId("record-field-changed"), Major, "field \{name} changed"))
        }
      }
    }
  })
  reasons
}

///| Structural equality of a constructor's parameter list, ignoring nothing
/// (unlike `Parameter`, `ConstructorParamShape` has no default-value field
/// to normalize away).
fn constructor_params_equal(
  old : Array[ConstructorParamShape]?,
  new : Array[ConstructorParamShape]?,
) -> Bool {
  old == new
}

///| Constructor-by-constructor diff of a `Variant`/`ExtensibleEnum`/
/// `ExtendEnum`/error-payload constructor list, keyed by name. `closed`
/// picks the rule id and level for an *added* constructor: `false` for
/// enums explicitly designed for growth (`ExtensibleEnum`/`ExtendEnum`),
/// `true` for everything else (`Variant`, error payloads), where a new case
/// breaks exhaustive matches.
fn diff_constructors(
  old : Array[ConstructorShape],
  new : Array[ConstructorShape],
  closed~ : Bool,
) -> Array[Reason] {
  let old_by_name = index_by_name(old, fn(c : ConstructorShape) { c.name })
  let new_by_name = index_by_name(new, fn(c : ConstructorShape) { c.name })
  let reasons : Array[Reason] = []
  old_by_name.keys().each(fn(name) {
    if !(new_by_name.contains(name)) {
      reasons.push((RuleId("enum-variant-removed"), Major, "constructor \{name} removed"))
    }
  })
  new_by_name.keys().each(fn(name) {
    if !(old_by_name.contains(name)) {
      if closed {
        reasons.push(
          (RuleId("enum-variant-added-closed"), Major, "constructor \{name} added"),
        )
      } else {
        reasons.push(
          (RuleId("enum-variant-added-extensible"), Minor, "constructor \{name} added"),
        )
      }
    }
  })
  old_by_name.keys().each(fn(name) {
    match new_by_name.get(name) {
      None => ()
      Some(nc) => {
        let oc = old_by_name.get(name).unwrap()
        if !(constructor_params_equal(oc.params, nc.params)) {
          reasons.push(
            (RuleId("enum-variant-changed"), Major, "constructor \{name}'s parameters changed"),
          )
        }
      }
    }
  })
  reasons
}

///| Compare two `TypeShape`s that share a `SymbolId`.
fn diff_type(old : TypeShape, new : TypeShape) -> Array[Reason] {
  let reasons : Array[Reason] = []
  diff_visibility(old.visibility, new.visibility).each(fn(r) { reasons.push(r) })
  diff_generics(old.generics, new.generics).each(fn(r) { reasons.push(r) })
  let old_derives = index_by_name(old.derives, fn(d : String) { d })
  let new_derives = index_by_name(new.derives, fn(d : String) { d })
  old_derives.keys().each(fn(d) {
    if !(new_derives.contains(d)) {
      reasons.push((RuleId("derive-removed"), Major, "derive(\{d}) removed"))
    }
  })
  new_derives.keys().each(fn(d) {
    if !(old_derives.contains(d)) {
      reasons.push((RuleId("derive-added"), Minor, "derive(\{d}) added"))
    }
  })
  if old.desc != new.desc {
    diff_type_desc(old.desc, new.desc).each(fn(r) { reasons.push(r) })
  }
  reasons
}
