///| A short, stable, human-readable explanation for a rule id, for
/// `--explain <rule>` and for tests asserting every rule this module can
/// actually emit has documentation. Returns `None` for an id this table
/// doesn't recognize, rather than panicking -- a `RuleId` a real `Change`
/// carries always comes from this module's own rule table, but a rule id
/// typed by hand on the command line, or read back from an old waiver file
/// written against a future version, might not match anything here, and
/// silently explaining nothing is safer than crashing a CI job over it.
///
/// Three ids below (`deprecated-marked`, `attr-reordered`, `doc-only`) are
/// part of Gate 2's PATCH rule table but **not yet detected by this M1**:
/// `surface`'s shapes don't currently carry deprecation attributes, raw
/// attribute ordering, or doc comments at all (they're stripped during
/// `ingest`), so `compare` can never actually produce them today. They stay
/// in this table -- with that limitation stated up front -- so
/// `--explain` never claims a documented rule doesn't exist, and so the gap
/// is visible to anyone reading the source rather than silently missing.
pub fn explain(rule : RuleId) -> String? {
  match rule.0 {
    // --- MAJOR --------------------------------------------------------
    "sym-removed" =>
      Some("A publicly visible declaration was removed entirely. Callers referencing it stop compiling.")
    "sym-kind-changed" =>
      Some("A symbol's identifier stayed but its kind changed (e.g. a function became a type). Extension beyond Gate 2's exact table: this is very unlikely in practice, since ingest's id scheme rarely collides across kinds, but is handled conservatively rather than silently ignored.")
    "func-param-required-added" =>
      Some("A new required (non-optional) parameter was added to a function or method. Existing call sites no longer supply it.")
    "func-param-removed" =>
      Some("A function or method lost one or more parameters (by count). Existing call sites that pass them stop compiling.")
    "func-param-type-changed" =>
      Some("An existing parameter's kind, label, or type changed. Existing call sites may no longer type-check.")
    "func-return-narrowed" =>
      Some("A function or method's return type changed. Treated conservatively as breaking in all directions: this M1 has no subtyping model to tell a narrowing change from a widening one.")
    "func-raise-added" =>
      Some("A function or method that previously could not raise now can. Callers that invoked it outside a `try`/`raise?` context stop compiling.")
    "func-raise-type-changed" =>
      Some("A function or method's raised error type changed (e.g. a different suberror, or switching between a specific type and the default). Extension beyond Gate 2's exact table: existing `catch` clauses may no longer match.")
    "async-changed" =>
      Some("A function or method's async-ness changed. Extension beyond Gate 2's exact table: this changes the calling convention outright.")
    "type-became-opaque" =>
      Some("A type that previously exposed structure (fields, a variant list, a wrapped type) became fully opaque. Code that pattern-matched, accessed fields, or constructed it directly stops compiling.")
    "enum-variant-added-closed" =>
      Some("A new constructor was added to a closed (non-extensible) enum or variant type. Exhaustive `match` expressions over it stop compiling.")
    "enum-variant-removed" =>
      Some("An existing enum/variant constructor was removed. Extension beyond Gate 2's exact table: code constructing or matching it stops compiling.")
    "enum-variant-changed" =>
      Some("An existing enum/variant constructor's parameters changed shape. Extension beyond Gate 2's exact table.")
    "record-field-added-pub-all" =>
      Some("A new publicly visible field was added to a record-like type. External struct-literal construction sites that don't already account for it may stop compiling.")
    "record-field-removed" =>
      Some("A field was removed from a record-like type. Code reading, writing, or constructing with that field stops compiling.")
    "record-field-changed" =>
      Some("An existing field's type, mutability, or visibility changed. Extension beyond Gate 2's exact table.")
    "derive-removed" =>
      Some("A `derive(...)` trait implementation was removed from a type. Code relying on that trait (e.g. `==`, `Show`/`Debug` output, hashing) stops compiling.")
    "impl-removed" =>
      Some("A `impl Trait for Type` declaration was removed. Code relying on that specific implementation stops compiling. A more specific spelling of `sym-removed` for this case.")
    "trait-method-added-no-default" =>
      Some("A trait gained a new method with no default implementation. Every existing implementor now fails to satisfy the trait.")
    "trait-method-removed" =>
      Some("A trait lost a method entirely. Extension beyond Gate 2's exact table: implementors providing it now have a stray, unused method (usually harmless) but anyone calling it through the trait stops compiling.")
    "trait-method-signature-changed" =>
      Some("An existing trait method's signature changed in any way (parameters, return type, generics, raise behavior, async-ness, or default-ness). Classified MAJOR unconditionally, even for a change that would only be MINOR on a free function: every implementor must match a trait method's signature exactly.")
    "trait-supertraits-changed" =>
      Some("A trait's supertrait list changed. Extension beyond Gate 2's exact table: conservatively MAJOR in both directions (a new requirement breaks existing implementors; even a removed one is flagged for review).")
    "as-free-fn-removed" =>
      Some("A method's `#as_free_fn`-generated free-function alias was removed. Callers using the free-function spelling stop compiling. A more specific spelling of `sym-removed` for this case.")
    "vis-narrowed" =>
      Some("A declaration's visibility became more restrictive (e.g. losing `pub(all)`, or becoming private). Code relying on the wider visibility stops compiling.")
    "generic-arity-changed" =>
      Some("The number of generic type parameters changed. Existing instantiations stop compiling.")
    "generic-constraint-changed" =>
      Some("A generic type parameter's trait constraints changed, without the count changing. Extension beyond Gate 2's exact table.")
    "alias-target-changed" =>
      Some("A type alias, `using`-re-export, or function alias now points somewhere different. Code relying on the previous target may behave differently or stop compiling.")
    "newtype-target-changed" =>
      Some("A newtype's wrapped (underlying) type changed. Extension beyond Gate 2's exact table.")
    "tuple-struct-shape-changed" =>
      Some("A tuple struct's positional component types changed. Extension beyond Gate 2's exact table.")
    "type-shape-kind-changed" =>
      Some("A type's declaration kind changed outright (e.g. a record became a variant). Extension beyond Gate 2's exact table.")
    "const-type-changed" =>
      Some("A public constant's declared type changed. Extension beyond Gate 2's exact table.")
    "value-type-changed" =>
      Some("A public top-level value's declared type changed. Extension beyond Gate 2's exact table.")
    "unsupported-changed" =>
      Some("Something ingest doesn't yet model precisely changed. Always classified MAJOR: the conservative default whenever certainty isn't available.")
    // --- MINOR ----------------------------------------------------------
    "sym-added" =>
      Some("A new publicly visible declaration was added. Existing callers are unaffected.")
    "func-param-optional-added" =>
      Some("A new trailing optional parameter was added to a function or method, with every existing parameter unchanged. Existing call sites remain valid.")
    "func-raise-removed" =>
      Some("A function or method that previously could raise no longer can. Classified MINOR, but always surfaced: a caller with a `try`/`catch` around the call may stop compiling even though the change is otherwise safe.")
    "derive-added" =>
      Some("A `derive(...)` trait implementation was added to a type. Existing code is unaffected; new code can now rely on it.")
    "impl-added" =>
      Some("A new `impl Trait for Type` declaration was added. Existing code is unaffected. A more specific spelling of `sym-added` for this case.")
    "trait-method-added-with-default" =>
      Some("A trait gained a new method that has a default implementation. Existing implementors remain valid without change.")
    "enum-variant-added-extensible" =>
      Some("A new constructor was added to an extensible enum or an `extend`-declared enum. These are designed for growth: exhaustive matching isn't expected against them.")
    "vis-widened" =>
      Some("A declaration's visibility became less restrictive (e.g. gaining `pub(all)`). Existing code is unaffected.")
    "record-field-added-opaque" =>
      Some("A new private field was added to a record-like type. It isn't part of the public surface, so external construction sites are unaffected.")
    "as-free-fn-added" =>
      Some("A method gained an `#as_free_fn`-generated free-function alias. Existing code is unaffected. A more specific spelling of `sym-added` for this case.")
    "type-desc-widened" =>
      Some("A type that was previously fully opaque gained visible structure (fields, a variant list, or a wrapped type). Extension beyond Gate 2's exact table: this only ever adds capabilities, so it's classified MINOR rather than ignored.")
    // --- PATCH ------------------------------------------------------------
    "import-list-changed" =>
      Some("A package's `import` list changed. Not part of symbol-by-symbol classification -- tracked separately since it can matter for build reproducibility even when no public symbol changed.")
    "opacity-unchanged" =>
      Some("A type's spelling changed between two equivalently opaque forms (e.g. `type Foo` and a record whose fields are all private). Not a real API change -- reported for visibility, not because it requires a version bump.")
    "const-value-changed" =>
      Some("A public constant's value changed, with its type unchanged. Extension beyond Gate 2's exact table: this can affect runtime behavior but never affects whether calling code compiles, which is this M1's entire scope.")
    "deprecated-marked" =>
      Some("A declaration was newly marked `#deprecated`. NOT YET DETECTED: `surface`'s shapes don't currently carry attribute information at all -- this id is documented for `--explain` but `compare` can never produce it in this version.")
    "attr-reordered" =>
      Some("Only the order of attributes on a declaration changed, with no other difference. NOT YET DETECTED: `surface` doesn't retain raw attribute ordering -- this id is documented for `--explain` but `compare` can never produce it in this version.")
    "doc-only" =>
      Some("Only a documentation comment changed. NOT YET DETECTED: `surface` doesn't retain doc comments at all -- this id is documented for `--explain` but `compare` can never produce it in this version.")
    _ => None
  }
}
