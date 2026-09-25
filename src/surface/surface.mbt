///| Location within a source `.mbti` file. `ingest` fills this in from
/// moonbitlang/parser's own `@basic.Location`; kept as our own type so
/// nothing outside `ingest` depends on the upstream parser's types.
pub(all) struct Span {
  start : Int
  end : Int
} derive(Eq, Debug)

///| Visibility as declared in `.mbti`. `VisPub`'s `attr` carries the
/// qualifier written inside the parens -- `"all"` for `pub(all)`, `"open"`
/// for `pub(open)` -- and is `None` for a plain `pub`. Source positions are
/// deliberately not part of this model: `compare` must be blind to *where*
/// in the file something is written, only to what changed.
pub(all) enum Visibility {
  VisDefault
  VisPub(attr~ : String?)
  VisPriv
} derive(Eq, Debug)

///| One function parameter. Mirrors moonbitlang/parser's `syntax.Parameter`
/// one-for-one (`DiscardPositional` / `Positional` / `Labelled` / `Optional`
/// / `QuestionOptional`) -- distinguishing these matters, since adding a
/// trailing `Optional` is non-breaking (minor) but adding a `Positional` or
/// `Labelled` parameter is breaking. `ty` (and `default`) are rendered to a
/// canonical string by `ingest` rather than kept as the upstream `Type`/
/// `Expr` AST: string equality is all `compare` needs, and it keeps this
/// package dependency-free.
pub(all) enum Parameter {
  DiscardPositional(ty~ : String)
  Positional(name~ : String, ty~ : String)
  Labelled(name~ : String, ty~ : String)
  Optional(name~ : String, ty~ : String, default~ : String)
  QuestionOptional(name~ : String, ty~ : String)
} derive(Eq, Debug)

///| A function's raise/error annotation, mirroring `syntax.ErrorType`.
/// Gaining a raise annotation (`NoErrorType`/`DefaultErrorType` moving to
/// `RaisesType`/`MaybeError`) is MAJOR; losing one (`func-raise-removed`) is
/// classified MINOR but always surfaced, since a caller with `try`/`catch`
/// around the call can still stop compiling.
pub(all) enum ErrorAnnotation {
  NoErrorType
  DefaultErrorType
  RaisesType(ty~ : String)
  Noraise
  MaybeError(ty~ : String)
} derive(Eq, Debug)

///| A free function, or a method when `method_of` holds the owner type's
/// rendered name (e.g. `Some("Array")` for a method on `Array`). Nothing in
/// `.mbti`'s `FuncSig` carries a separate visibility field: if a function is
/// listed at all, it is already public -- so unlike `TypeShape`/`TraitShape`
/// there is no `visibility` field here.
///
/// `nocancel_` (whether the function opts out of async cancellation) is
/// intentionally not modelled in v1 -- documented gap, not a silent drop;
/// revisit if it turns out to matter for compatibility.
pub(all) struct FuncShape {
  method_of : String?
  generics : Array[String]
  params : Array[Parameter]
  return_type : String
  error_annotation : ErrorAnnotation
  is_async : Bool
} derive(Eq, Debug)

pub(all) struct FieldShape {
  name : String
  ty : String
  is_mutable : Bool
  visibility : Visibility
} derive(Eq, Debug)

///| One constructor parameter of a `Variant`/`ExtensibleEnum` case, mirroring
/// `syntax.ConstrParam`.
pub(all) struct ConstructorParamShape {
  ty : String
  is_mutable : Bool
  label : String?
} derive(Eq, Debug)

///| One enum/variant constructor, e.g. `Some(Int)` or a bare `Red`. `params`
/// is `None` for a constructor written with no parentheses at all, distinct
/// from an explicit empty argument list -- matching moonbitlang/parser's own
/// `ConstrDecl.args : List[ConstrParam]?`.
pub(all) struct ConstructorShape {
  name : String
  params : Array[ConstructorParamShape]?
} derive(Eq, Debug)

///| What kind of type declaration this is. Mirrors moonbitlang/parser's
/// `mbti_ast.TypeDefinition` one-for-one -- notably `Newtype` (`type Age
/// Int`, a single wrapped type) is a *distinct* case from `TupleStruct`
/// (`type Pair(Int, Int)`, positional multi-field), and both are distinct
/// from `Abstract` (fully opaque, `type Foo`) and a `Record` whose fields
/// are all private (opaque in effect). `compare` treats switching between
/// the latter two spellings as PATCH (`opacity-unchanged`), not as a real
/// API change; switching between `Newtype`/`TupleStruct`/`Abstract`/`Record`
/// otherwise is a real shape change.
pub(all) enum TypeDesc {
  Abstract
  Newtype(target~ : String)
  TupleStruct(components~ : Array[String])
  ErrorDecl(payload~ : Array[ConstructorShape])
  ExtensibleEnum(constructors~ : Array[ConstructorShape])
  ExtendEnum(target~ : String, constructors~ : Array[ConstructorShape])
  Variant(constructors~ : Array[ConstructorShape])
  Record(fields~ : Array[FieldShape])
  AliasDesc(target~ : String)
} derive(Eq, Debug)

pub(all) struct TypeShape {
  visibility : Visibility
  generics : Array[String]
  desc : TypeDesc
  derives : Array[String]
} derive(Eq, Debug)

///| Unlike `FuncShape`, no `visibility` field -- a trait method's visibility
/// is not tracked separately from the trait's own (`TraitShape.visibility`).
pub(all) struct TraitMethodShape {
  name : String
  generics : Array[String]
  params : Array[Parameter]
  return_type : String
  error_annotation : ErrorAnnotation
  is_async : Bool
  has_default : Bool
} derive(Eq, Debug)

pub(all) struct TraitShape {
  visibility : Visibility
  methods : Array[TraitMethodShape]
  supertraits : Array[String]
} derive(Eq, Debug)

pub(all) struct ImplShape {
  trait_name : String
  type_name : String
  generics : Array[String]
} derive(Eq, Debug)

///| `.mbti`'s `ConstSig` carries no visibility field of its own -- appearing
/// in the file at all already means public.
pub(all) struct ConstShape {
  ty : String
  value : String
} derive(Eq, Debug)

///| Same note as `ConstShape`: `.mbti`'s `ValueSig` has no visibility field.
pub(all) struct ValueShape {
  ty : String
} derive(Eq, Debug)

///| `.mbti`'s `Alias` sig covers three distinct mechanisms upstream
/// (`mbti_ast.AliasSig`): a real type alias (`TypeAliasShape`), a `using`
/// re-export of another package's symbol under a (possibly renamed) local
/// name (`UsingShape`), and a function-alias -- the mechanism behind Gate
/// 2's `as-free-fn-*` rules (`FuncAliasShape`).
pub(all) enum AliasShape {
  TypeAliasShape(target~ : String, visibility~ : Visibility, generics~ : Array[String])
  UsingShape(pkg~ : String, target~ : String, local_name~ : String?)
  FuncAliasShape(type_name~ : String)
} derive(Eq, Debug)

///| A stable, opaque identifier for one symbol within a `Surface`. `ingest`
/// derives these deterministically (e.g. `"TypeName::method_name"` for a
/// method) so `compare` matches old vs. new symbols by identity rather than
/// by position in the file.
pub(all) struct SymbolId(String) derive(Eq, Hash, Debug, Compare)

///| One public declaration, normalized from `.mbti` into a shape `compare`
/// can reason about. `Unsupported` is the conservative fallback: any
/// construct `ingest` doesn't yet model is carried here verbatim, with its
/// source span, rather than dropped -- `compare` always treats it as a
/// potential MAJOR change rather than silently reporting "no breaking
/// changes".
pub(all) enum Symbol {
  Func(FuncShape)
  Type(TypeShape)
  Trait(TraitShape)
  Impl(ImplShape)
  Const(ConstShape)
  Value(ValueShape)
  Alias(AliasShape)
  Unsupported(raw~ : String, loc~ : Span)
} derive(Eq, Debug)

///| The full normalized public surface of one `.mbti` file (one package).
/// `imports` is tracked separately from `symbols`: a changed import list is
/// PATCH-level (Gate 2's `import-list-changed`), not part of the
/// symbol-by-symbol MAJOR/MINOR/PATCH classification.
pub(all) struct Surface {
  package_name : String
  imports : Array[String]
  symbols : Map[SymbolId, Symbol]
}

///| Look up a single symbol by id.
pub fn Surface::symbol(self : Surface, id : SymbolId) -> Symbol? {
  self.symbols.get(id)
}
