///| Single shared `using` block for the whole `compare` package, mirroring
/// the convention `moonbitlang/parser` itself uses internally (one
/// `imports.mbt` file per package, e.g. `mbti_ast/imports.mbt`,
/// `syntax/imports.mbt`) rather than repeating `using` in every file.
/// `compare` deliberately depends on nothing but `surface` -- pure,
/// deterministic, no upstream parser dependency, per Gate 2's package
/// layout -- so unlike `ingest` there is no cross-module name collision risk
/// in bringing all of `surface`'s constructors into unprefixed scope here.
/// Every other file in this package relies on this block for pattern
/// matching on `Symbol`, `TypeDesc`, `Visibility`, `Parameter`,
/// `ErrorAnnotation`, and `AliasShape` variants.
using @surface {
  type Symbol,
  type Surface,
  type SymbolId,
  type Span,
  type Visibility,
  type Parameter,
  type ErrorAnnotation,
  type FuncShape,
  type FieldShape,
  type ConstructorParamShape,
  type ConstructorShape,
  type TypeDesc,
  type TypeShape,
  type TraitMethodShape,
  type TraitShape,
  type ImplShape,
  type ConstShape,
  type ValueShape,
  type AliasShape,
}
