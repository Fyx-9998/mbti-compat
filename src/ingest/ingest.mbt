// Bring upstream constructors into unprefixed scope for pattern matching,
// mirroring the exact idiom moonbitlang/parser's own source uses internally
// (e.g. mbti_parser/imports.mbt's `using @mbti_ast { ... }` block). Our own
// `surface` types are deliberately NOT brought in this way -- several of
// their variant names (e.g. `ErrorAnnotation::NoErrorType`, every
// `Parameter` variant, most of `TypeDesc`) intentionally mirror upstream
// names one-for-one, so constructing them is always written fully qualified
// as `@surface.Enum::Variant(...)` to stay unambiguous.
using @mbti_ast {
  type Sig,
  type FuncSig,
  type TypeSig,
  type TraitSig,
  type ImplSig,
  type ConstSig,
  type ValueSig,
  type AliasSig,
  type PackageImport,
  type TypeDefinition,
  type TypeParamWithConstraints,
  type TypeParamNoConstraints,
  type TraitMethodSig,
  type MethodSelfType,
  type Name,
  type QualifiedName,
}

using @syntax {
  type Visibility,
  type ErrorType,
  type Parameter,
  type Constant,
  type ConstrDecl,
  type ConstrParam,
  type FieldDecl,
  type LongIdent,
  type Type,
  type Expr,
  type Label,
  type ConstrId,
}

using @basic { type Location }

///| Failure modes for turning `.mbti` source text into a `surface.Surface`.
/// Gate 2's design sketch also proposed an `Unrecognized` case for a
/// partially-parsed file with an unrecognized fragment; dropped here because
/// `moonbitlang/parser/mbti_parser.parse_string` doesn't actually have that
/// mode -- it either fully succeeds or fully fails (a non-empty report
/// array). Per-symbol "I don't fully understand this" is instead handled
/// inside a successful parse by `surface.Symbol::Unsupported`, not by this
/// error type.
pub suberror IngestError {
  Parse(file~ : String, span~ : @surface.Span, message~ : String)
} derive(Eq, Debug)

///| Parse `.mbti` source text into a normalized `surface.Surface`. `name` is
/// used only for diagnostics (the file name embedded in error messages),
/// matching `mbti_parser.parse_string`'s own `name?` parameter one-for-one.
pub fn of_mbti_source(source : String, name? : String = "") -> @surface.Surface raise IngestError {
  let (mbti, reports) = @mbti_parser.parse_string(source, name~)
  if reports.length() > 0 {
    let r = reports[0]
    raise Parse(file=name, span=to_span(r.loc), message=r.msg)
  }
  let imports = mbti.imports.map(render_import).to_array()
  let symbols : Map[@surface.SymbolId, @surface.Symbol] = Map([])
  mbti.sigs.each(fn(pair) {
    let (sig, _loc) = pair
    let (id, sym) = convert_sig(sig)
    symbols.set(id, sym)
  })
  @surface.Surface::{ package_name: mbti.package_name, imports, symbols }
}

// ---------------------------------------------------------------------------
// Mbti -> Surface: one converter per Sig variant
// ---------------------------------------------------------------------------

fn convert_sig(sig : Sig) -> (@surface.SymbolId, @surface.Symbol) {
  match sig {
    Func(f) => convert_func(f)
    Type(t) => convert_type(t)
    Trait(t) => convert_trait(t)
    Impl(i) => convert_impl(i)
    Const(c) => convert_const(c)
    Value(v) => convert_value(v)
    Alias(a) => convert_alias(a)
  }
}

fn convert_func(f : FuncSig) -> (@surface.SymbolId, @surface.Symbol) {
  let method_of = f.type_name.map(fn(mst : MethodSelfType) { mst.name })
  let (ret_ty, err_ty) = f.return_
  let shape = @surface.FuncShape::{
    method_of,
    generics: render_type_params_with_constraints(f.type_params),
    params: f.params.map(render_parameter).to_array(),
    return_type: render_type(ret_ty),
    error_annotation: render_error_type(err_ty),
    is_async: f.is_async is Some(_),
  }
  let id = match method_of {
    Some(owner) => @surface.SymbolId("\{owner}::\{f.name.name}")
    None => @surface.SymbolId(f.name.name)
  }
  (id, @surface.Symbol::Func(shape))
}

fn convert_type(t : TypeSig) -> (@surface.SymbolId, @surface.Symbol) {
  let shape = @surface.TypeShape::{
    visibility: render_visibility(t.vis),
    generics: render_type_params_no_constraints(t.type_params),
    desc: render_type_definition(t.components),
    derives: t.derives.map(render_qualified_name).to_array(),
  }
  (@surface.SymbolId(t.name.name), @surface.Symbol::Type(shape))
}

fn convert_trait(t : TraitSig) -> (@surface.SymbolId, @surface.Symbol) {
  let shape = @surface.TraitShape::{
    visibility: render_visibility(t.vis),
    methods: t.methods.map(render_trait_method).to_array(),
    supertraits: t.super_traits.map(render_qualified_name).to_array(),
  }
  (@surface.SymbolId(t.name.name), @surface.Symbol::Trait(shape))
}

fn render_trait_method(m : TraitMethodSig) -> @surface.TraitMethodShape {
  let (ret_ty, err_ty) = m.return_
  @surface.TraitMethodShape::{
    name: m.name.name,
    generics: render_type_params_with_constraints(m.type_params),
    params: m.params.map(render_parameter).to_array(),
    return_type: render_type(ret_ty),
    error_annotation: render_error_type(err_ty),
    is_async: m.is_async is Some(_),
    has_default: m.has_default,
  }
}

fn convert_impl(i : ImplSig) -> (@surface.SymbolId, @surface.Symbol) {
  let shape = @surface.ImplShape::{
    trait_name: render_qualified_name(i.trait_name),
    type_name: render_type(i.type_),
    generics: render_type_params_with_constraints(i.type_params),
  }
  let id = @surface.SymbolId("impl \{shape.trait_name} for \{shape.type_name}")
  (id, @surface.Symbol::Impl(shape))
}

fn convert_const(c : ConstSig) -> (@surface.SymbolId, @surface.Symbol) {
  let shape = @surface.ConstShape::{ ty: render_type(c.type_), value: render_constant(c.value) }
  (@surface.SymbolId(c.name.name), @surface.Symbol::Const(shape))
}

fn convert_value(v : ValueSig) -> (@surface.SymbolId, @surface.Symbol) {
  let shape = @surface.ValueShape::{ ty: render_type(v.type_) }
  (@surface.SymbolId(v.name.name), @surface.Symbol::Value(shape))
}

fn convert_alias(a : AliasSig) -> (@surface.SymbolId, @surface.Symbol) {
  match a {
    TypeAlias(name~, type_params~, type_~, vis~, ..) => {
      let shape = @surface.AliasShape::TypeAliasShape(
        target=render_type(type_),
        visibility=render_visibility(vis),
        generics=render_type_params_no_constraints(type_params),
      )
      (@surface.SymbolId(name.name), @surface.Symbol::Alias(shape))
    }
    Using(pkg~, target~, name~, ..) => {
      let local_alias = name.map(fn(n : Name) { n.name })
      let shape = @surface.AliasShape::UsingShape(
        pkg=pkg.name,
        target=target.name,
        local_name=local_alias,
      )
      let id_name = match local_alias {
        Some(n) => n
        None => target.name
      }
      (@surface.SymbolId(id_name), @surface.Symbol::Alias(shape))
    }
    FuncAlias(name~, type_name~, ..) => {
      let shape = @surface.AliasShape::FuncAliasShape(type_name=type_name.name)
      (@surface.SymbolId(name.name), @surface.Symbol::Alias(shape))
    }
  }
}

// ---------------------------------------------------------------------------
// Leaf renderers: syntax.* -> surface.* (or String, for Type/Constant/Expr)
// ---------------------------------------------------------------------------

fn render_import(imp : PackageImport) -> String {
  match imp.alias_ {
    Some(a) => "\{imp.name} as \{a}"
    None => imp.name
  }
}

fn render_visibility(v : Visibility) -> @surface.Visibility {
  match v {
    Default => @surface.Visibility::VisDefault
    Pub(attr~, ..) => @surface.Visibility::VisPub(attr=attr)
    Priv(..) => @surface.Visibility::VisPriv
  }
}

fn render_error_type(et : ErrorType) -> @surface.ErrorAnnotation {
  match et {
    NoErrorType => @surface.ErrorAnnotation::NoErrorType
    DefaultErrorType(..) => @surface.ErrorAnnotation::DefaultErrorType
    ErrorType(ty~) => @surface.ErrorAnnotation::RaisesType(ty=render_type(ty))
    Noraise(..) => @surface.ErrorAnnotation::Noraise
    MaybeError(ty~) => @surface.ErrorAnnotation::MaybeError(ty=render_type(ty))
  }
}

fn render_parameter(p : Parameter) -> @surface.Parameter {
  match p {
    DiscardPositional(ty~, ..) =>
      @surface.Parameter::DiscardPositional(ty=render_type_opt(ty))
    Positional(binder~, ty~) =>
      @surface.Parameter::Positional(name=binder.name, ty=render_type_opt(ty))
    Labelled(binder~, ty~) =>
      @surface.Parameter::Labelled(name=binder.name, ty=render_type_opt(ty))
    Optional(binder~, default~, ty~) =>
      @surface.Parameter::Optional(
        name=binder.name,
        ty=render_type_opt(ty),
        default=render_expr_shallow(default),
      )
    QuestionOptional(binder~, ty~) =>
      @surface.Parameter::QuestionOptional(name=binder.name, ty=render_type_opt(ty))
  }
}

fn render_type_opt(ty : Type?) -> String {
  match ty {
    Some(t) => render_type(t)
    None => "_"
  }
}

/// Renders `syntax.Type` to a canonical string. String equality of this
/// output is all `compare` ever needs -- it never re-parses or structurally
/// walks a `Type` again -- so this is the single place type-rendering
/// determinism has to hold.
fn render_type(ty : Type) -> String {
  match ty {
    Any(..) => "Any"
    Arrow(args~, res~, err~, is_async~, ..) => {
      let args_str = args.map(render_type).to_array().join(", ")
      let prefix = if is_async is Some(_) { "async " } else { "" }
      let suffix = render_error_type_suffix(err)
      "\{prefix}(\{args_str}) -> \{render_type(res)}\{suffix}"
    }
    Tuple(tys~, ..) => {
      let parts = tys.map(render_type).to_array().join(", ")
      "(\{parts})"
    }
    Name(constr_id~, tys~, ..) => {
      let base = render_constr_id(constr_id)
      if tys.is_empty() {
        base
      } else {
        let args_str = tys.map(render_type).to_array().join(", ")
        "\{base}[\{args_str}]"
      }
    }
    Option(ty~, ..) => "\{render_type(ty)}?"
    Object(constr_id) => "object \{render_constr_id(constr_id)}"
  }
}

fn render_error_type_suffix(et : ErrorType) -> String {
  match et {
    NoErrorType => ""
    DefaultErrorType(..) => " raise"
    ErrorType(ty~) => " raise \{render_type(ty)}"
    Noraise(..) => " noraise"
    MaybeError(ty~) => " raise? \{render_type(ty)}"
  }
}

fn render_constr_id(cid : ConstrId) -> String {
  render_long_ident(cid.id)
}

fn render_long_ident(li : LongIdent) -> String {
  match li {
    Ident(name~) => name
    Dot(pkg~, id~) => "\{pkg}.\{id}"
  }
}

fn render_qualified_name(qn : QualifiedName) -> String {
  render_long_ident(qn.name)
}

fn render_type_params_with_constraints(
  tps : @list.List[TypeParamWithConstraints],
) -> Array[String] {
  tps.map(fn(tp) {
    if tp.constraints.is_empty() {
      tp.name.name
    } else {
      let cs = tp.constraints.map(render_qualified_name).to_array().join(" + ")
      "\{tp.name.name} : \{cs}"
    }
  }).to_array()
}

fn render_type_params_no_constraints(
  tps : @list.List[TypeParamNoConstraints],
) -> Array[String] {
  tps.map(fn(tp) {
    match tp {
      Name(n) => n.name
      Underscore(_) => "_"
    }
  }).to_array()
}

/// Only handles a literal `Constant` default (covers the overwhelming
/// majority of real `.mbti` defaults: `= 0`, `= ""`, `= true`, ...). Any
/// other default expression renders as the placeholder `"<expr>"` --
/// documented, not hidden: exact default *values* don't affect
/// MAJOR/MINOR/PATCH classification (only whether a parameter is optional at
/// all does), so this is informational-only, not a correctness gap in
/// `compare`.
fn render_expr_shallow(e : Expr) -> String {
  match e {
    Constant(c~, ..) => render_constant(c)
    _ => "<expr>"
  }
}

fn render_constant(c : Constant) -> String {
  match c {
    Bool(b) => if b { "true" } else { "false" }
    Byte(s) => "b'\{s}'"
    Bytes(s) => "b\"\{s}\""
    Char(s) => "'\{s}'"
    Int(s) => s
    Int64(s) => "\{s}L"
    UInt(s) => "\{s}U"
    UInt64(s) => "\{s}UL"
    Float(s) => s
    Double(s) => s
    String(s) => "\"\{s}\""
    Regex(s) => "/\{s}/"
    BigInt(s) => "\{s}N"
  }
}

fn render_type_definition(td : TypeDefinition) -> @surface.TypeDesc {
  match td {
    Abstract => @surface.TypeDesc::Abstract
    Newtype(ty) => @surface.TypeDesc::Newtype(target=render_type(ty))
    TupleStruct(tys) =>
      @surface.TypeDesc::TupleStruct(components=tys.map(render_type).to_array())
    Error(decl) =>
      match decl {
        NoPayload => @surface.TypeDesc::ErrorDecl(payload=[])
        EnumPayload(cs) => @surface.TypeDesc::ErrorDecl(payload=render_constructors(cs))
      }
    ExtensibleEnum(cs) =>
      @surface.TypeDesc::ExtensibleEnum(constructors=render_constructors(cs))
    ExtendEnum(target~, constructors~) =>
      @surface.TypeDesc::ExtendEnum(
        target=render_qualified_name(target),
        constructors=render_constructors(constructors),
      )
    Variant(cs) => @surface.TypeDesc::Variant(constructors=render_constructors(cs))
    Record(fields~) => @surface.TypeDesc::Record(fields=render_fields(fields))
    Alias(ty) => @surface.TypeDesc::AliasDesc(target=render_type(ty))
  }
}

fn render_fields(fields : @list.List[FieldDecl]) -> Array[@surface.FieldShape] {
  fields.map(fn(f) {
    @surface.FieldShape::{
      name: f.name.label,
      ty: render_type(f.ty),
      is_mutable: f.mut_,
      visibility: render_visibility(f.vis),
    }
  }).to_array()
}

fn render_constructors(cs : @list.List[ConstrDecl]) -> Array[@surface.ConstructorShape] {
  cs.map(fn(c) {
    let params = match c.args {
      None => None
      Some(ps) => Some(ps.map(render_constr_param).to_array())
    }
    @surface.ConstructorShape::{ name: c.name.name, params }
  }).to_array()
}

fn render_constr_param(p : ConstrParam) -> @surface.ConstructorParamShape {
  @surface.ConstructorParamShape::{
    ty: render_type(p.ty),
    is_mutable: p.mut_,
    label: p.label.map(fn(l : Label) { l.name }),
  }
}

fn to_span(loc : Location) -> @surface.Span {
  @surface.Span::{ start: loc.start.cnum, end: loc.end.cnum }
}
