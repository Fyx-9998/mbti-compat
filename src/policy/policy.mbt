///| A released version number, `MAJOR.MINOR.PATCH` -- the type
/// `required_version`/`verdict` operate on. Gate 2's design brief names
/// `Version` in every M2 signature but never defines its own shape, so this
/// is this project's own design: three plain, non-negative `Int` fields,
/// mirroring how every other version scheme (SemVer itself, Cargo, npm)
/// represents a release number. No pre-release/build-metadata suffix
/// (`-alpha.1`, `+build5`) is supported in this first pass -- `Version::parse`
/// raises on anything that isn't exactly three dot-separated non-negative
/// integers, rather than silently truncating or guessing.
pub(all) struct Version {
  major : Int
  minor : Int
  patch : Int
} derive(Eq, Debug)

///| Manual `Compare` impl rather than `derive(Compare)`: a derived `Compare`
/// on an `enum` (like `compare::Level`, see that type's own comment) has
/// already been proven, by real, passing `moon test` runs, to compare in
/// field/variant declaration order -- but that has only ever been confirmed
/// for a single-field-per-comparison `enum`, never for a multi-field
/// `struct` where the *intended* ordering (major, then minor, then patch)
/// must not depend on an unproven assumption about derived struct-field
/// ordering. Writing `compare` out by hand removes that doubt entirely.
pub impl Compare for Version with fn compare(self, other) {
  if self.major != other.major {
    self.major.compare(other.major)
  } else if self.minor != other.minor {
    self.minor.compare(other.minor)
  } else {
    self.patch.compare(other.patch)
  }
}

///| A human-readable `"MAJOR.MINOR.PATCH"` rendering, e.g. for an
/// `Insufficient` verdict's error message. Not `derive(Show)` (deprecated,
/// see gate3-decisions-and-plan.md's "Real syntax/API corrections") and not
/// interpolated via a `derive(Debug)`-only path -- an explicit method,
/// mirroring `src/report/report.mbt`'s `level_word` (the project's standing
/// answer to "how do we turn one of our own enums/structs into text").
pub fn Version::to_string(self : Version) -> String {
  "\{self.major}.\{self.minor}.\{self.patch}"
}

///| Raised by `Version::parse` when its argument isn't exactly three
/// dot-separated non-negative integers. Single-variant, carrying the
/// original text back so a caller can build a precise error message without
/// re-deriving it -- same shape as `src/ingest`'s `IngestError`.
pub suberror VersionError {
  InvalidFormat(raw~ : String)
} derive(Eq, Debug)

///| Parse a plain `"MAJOR.MINOR.PATCH"` string (no leading `v`, no
/// pre-release/build suffix) into a `Version`. `@string.parse_int` (from
/// `moonbitlang/core/string`, NOT the `internal/strconv` package a substring
/// of that name lives in -- `internal` packages aren't importable from
/// outside their own module) is the real, ground-truthed way to parse a
/// `StringView` into an `Int`; the `catch { _ => raise InvalidFormat(...) }`
/// shape converting its (unnamed, unconstrained) error into our own
/// `VersionError` is copied verbatim from `moonbitlang/async/src/http/
/// request.mbt`'s real `let port = @string.parse_int(port_str) catch {
/// _ => raise InvalidFormat }`.
pub fn Version::parse(raw : String) -> Version raise VersionError {
  let parts = raw.split(".").to_array()
  guard parts.length() == 3 else { raise InvalidFormat(raw~) }
  let major = @string.parse_int(parts[0]) catch {
    _ => raise InvalidFormat(raw~)
  }
  let minor = @string.parse_int(parts[1]) catch {
    _ => raise InvalidFormat(raw~)
  }
  let patch = @string.parse_int(parts[2]) catch {
    _ => raise InvalidFormat(raw~)
  }
  guard major >= 0 && minor >= 0 && patch >= 0 else { raise InvalidFormat(raw~) }
  { major, minor, patch }
}

///| The minimum version that satisfies `delta` on top of `baseline`, per
/// Gate 2's design brief ("M2 version verdict: policy incl. 0.x"). Standard
/// SemVer bump rules for `baseline.major >= 1`; for `baseline.major == 0`
/// this follows the same widely-used "pre-1.0 has no stable major" reading
/// Cargo itself uses for `^0.y.z` requirements (this project's own stated
/// model is "the MoonBit analogue of cargo-semver-checks" -- see
/// gate1-candidate-research.md): a MAJOR-level change only needs `minor`
/// bumped (`0.y.z -> 0.(y+1).0`), and a MINOR-level change only needs
/// `patch` bumped (`0.y.z -> 0.y.(z+1)`), since `major` staying `0` already
/// signals "no compatibility promise" and there is no room below `minor` to
/// protect once `major` is pinned at `0`. A PATCH-level delta never requires
/// a bump at all -- `baseline` is returned unchanged.
///
/// Known, documented gap: `0.0.z` (no stable *minor* either) still follows
/// the `0.x` rule above rather than requiring every change, even PATCH, to
/// bump `patch` -- some tools (Cargo included) special-case `0.0.z` further.
/// Not implemented here; revisit if the owner asks for it.
pub fn required_version(baseline~ : Version, delta~ : Delta) -> Version {
  // `Level` explicitly annotated here (rather than left for `delta.level()`'s
  // return type to be inferred) so the `type Level` brought into scope by
  // imports.mbt is provably *used* -- the real toolchain's own `moon check`
  // flagged `type Level` as an unused type declaration when nothing in this
  // file ever spelled the type name out, even though the match below already
  // used its three variants (Patch/Minor/Major) unqualified. `report.mbt`'s
  // own `level_word`/`colorize` avoid the same warning by writing `Level` as
  // a parameter type; this file has no such parameter to hang it on, so a
  // `let ... : Level` binding is this file's equivalent.
  let level : Level = delta.level()
  match level {
    Patch => baseline
    Minor =>
      if baseline.major == 0 {
        { major: 0, minor: baseline.minor, patch: baseline.patch + 1 }
      } else {
        { major: baseline.major, minor: baseline.minor + 1, patch: 0 }
      }
    Major =>
      if baseline.major == 0 {
        { major: 0, minor: baseline.minor + 1, patch: 0 }
      } else {
        { major: baseline.major + 1, minor: 0, patch: 0 }
      }
  }
}

///| Whether a `declared` version bump is enough to cover `delta`, given the
/// currently-published `baseline`. Gate 2's design brief's own signature
/// (`pub(all) enum Verdict { Sufficient(Version); Insufficient(required~ :
/// Version, declared~ : Version) }`) leaves open which version
/// `Sufficient` carries -- this build carries `declared` (the version that
/// was found sufficient), by symmetry with `Insufficient` naming its own
/// `declared~` field explicitly rather than assuming the caller already has
/// it in scope.
pub(all) enum Verdict {
  Sufficient(Version)
  Insufficient(required~ : Version, declared~ : Version)
} derive(Eq, Debug)

///|
pub fn verdict(
  baseline~ : Version,
  declared~ : Version,
  delta~ : Delta,
) -> Verdict {
  let required = required_version(baseline~, delta~)
  // `Compare::compare(declared, required)`, not `declared.compare(required)`
  // -- the real toolchain's own `moon check` flagged the dot-call as
  // `[0020] deprecated`: "The method `compare` is implicitly promoted from
  // `impl Compare for Version`... either use `Compare::compare` instead or
  // add a `extend Version with Compare::{compare, ..}` declaration." Taking
  // the compiler's own first-listed fix (the explicit trait-qualified call)
  // rather than the `extend` declaration, since that's real, ground-truthed
  // syntax straight from the diagnostic itself, not a pattern this project
  // has had to separately verify against upstream source.
  if Compare::compare(declared, required) >= 0 {
    Sufficient(declared)
  } else {
    Insufficient(required~, declared~)
  }
}
