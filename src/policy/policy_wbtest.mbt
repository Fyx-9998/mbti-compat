///| Field-by-field comparisons throughout this file, never a whole-`Version`/
/// `Verdict` `==`/`!=` or a bare-literal comparison operand -- matching
/// `src/cmd/mbti-compat/cli_wbtest.mbt`'s own established pattern (its tests
/// compare `opts.old_path`, `opts.json`, etc. individually, never `opts !=
/// CheckOptions::{...}`), the only proven precedent this project has for
/// asserting on a multi-field result. `Version::{ major: ..., ... }` (the
/// one place this file *does* construct a `Version` literal, for
/// `required_version`'s `baseline~` argument) is written fully qualified
/// with the `Type::{...}` form already proven in `main.mbt`'s
/// `@surface.Surface::{...}`, not a bare `{...}` literal.

///|
test "Version::parse accepts well-formed major.minor.patch strings" {
  let failures : Array[String] = []
  try {
    let v1 = Version::parse("1.2.3")
    if v1.major != 1 || v1.minor != 2 || v1.patch != 3 {
      failures.push(
        "expected \"1.2.3\" to parse to 1.2.3, got \{v1.major}.\{v1.minor}.\{v1.patch}",
      )
    }
    let v2 = Version::parse("0.0.0")
    if v2.major != 0 || v2.minor != 0 || v2.patch != 0 {
      failures.push(
        "expected \"0.0.0\" to parse to 0.0.0, got \{v2.major}.\{v2.minor}.\{v2.patch}",
      )
    }
    let v3 = Version::parse("10.20.30")
    if v3.major != 10 || v3.minor != 20 || v3.patch != 30 {
      failures.push(
        "expected \"10.20.30\" to parse to 10.20.30, got \{v3.major}.\{v3.minor}.\{v3.patch}",
      )
    }
  } catch {
    _ => failures.push("Version::parse raised unexpectedly on well-formed input")
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}

///| Every one of these is missing a segment, has too many, has a
/// non-numeric segment, is empty, or has a negative segment -- each must
/// raise `VersionError`, never silently produce a `Version`.
test "Version::parse rejects malformed input" {
  let bad : Array[String] = ["1.2", "1.2.3.4", "a.b.c", "", "1.-2.3", "1..3"]
  let failures : Array[String] = []
  bad.each(fn(raw) {
    try {
      let _ = Version::parse(raw)
      failures.push(
        "expected Version::parse(\"\{raw}\") to raise, but it succeeded",
      )
    } catch {
      _ => ()
    }
  })
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}

///| Three tiny `.mbti` fixture pairs, one per `Level` -- self-compare for
/// `Patch` (reflexivity, already proven project-wide), one function added
/// for `Minor` (`sym-added`), one function removed for `Major`
/// (`sym-removed`) -- the exact same fixture shapes `report_wbtest.mbt` and
/// `inverse_and_noise_wbtest.mbt` already use, reused here rather than
/// hand-constructing `Delta`/`Change` struct literals directly (which nothing
/// else in this project does, even though `Delta`/`Change` are `pub(all)`).
fn patch_delta() -> Delta raise {
  let source = "package \"test/policy\"\n\npub fn foo() -> Unit\n"
  let surface = @ingest.of_mbti_source(source, name="policy")
  @compare.compare(old=surface, new=surface)
}

///|
fn minor_delta() -> Delta raise {
  let without_foo = @ingest.of_mbti_source(
    "package \"test/policy\"\n", name="policy",
  )
  let with_foo = @ingest.of_mbti_source(
    "package \"test/policy\"\n\npub fn foo() -> Unit\n", name="policy",
  )
  @compare.compare(old=without_foo, new=with_foo)
}

///|
fn major_delta() -> Delta raise {
  let with_foo = @ingest.of_mbti_source(
    "package \"test/policy\"\n\npub fn foo() -> Unit\n", name="policy",
  )
  let without_foo = @ingest.of_mbti_source(
    "package \"test/policy\"\n", name="policy",
  )
  @compare.compare(old=with_foo, new=without_foo)
}

///|
test "required_version leaves a >=1.0 baseline unchanged for a Patch delta" {
  try {
    let delta = patch_delta()
    let baseline = Version::{ major: 1, minor: 2, patch: 3 }
    let result = required_version(baseline~, delta~)
    if result.major != 1 || result.minor != 2 || result.patch != 3 {
      fail(
        "expected 1.2.3 unchanged, got \{result.major}.\{result.minor}.\{result.patch}",
      )
    }
  } catch {
    _ => fail("failed to build a Patch-level fixture delta")
  }
}

///|
test "required_version bumps minor and zeroes patch for a Minor delta on a >=1.0 baseline" {
  try {
    let delta = minor_delta()
    let baseline = Version::{ major: 1, minor: 2, patch: 3 }
    let result = required_version(baseline~, delta~)
    if result.major != 1 || result.minor != 3 || result.patch != 0 {
      fail(
        "expected 1.3.0, got \{result.major}.\{result.minor}.\{result.patch}",
      )
    }
  } catch {
    _ => fail("failed to build a Minor-level fixture delta")
  }
}

///|
test "required_version bumps major and zeroes minor+patch for a Major delta on a >=1.0 baseline" {
  try {
    let delta = major_delta()
    let baseline = Version::{ major: 1, minor: 2, patch: 3 }
    let result = required_version(baseline~, delta~)
    if result.major != 2 || result.minor != 0 || result.patch != 0 {
      fail(
        "expected 2.0.0, got \{result.major}.\{result.minor}.\{result.patch}",
      )
    }
  } catch {
    _ => fail("failed to build a Major-level fixture delta")
  }
}

///| The 0.x rules: a Major-level delta only needs `minor` bumped (major
/// stays 0), and a Minor-level delta only needs `patch` bumped -- there is
/// no room below `minor` to protect once `major` is pinned at 0.
test "required_version applies 0.x rules for a 0.x baseline" {
  try {
    let baseline = Version::{ major: 0, minor: 5, patch: 2 }
    let minor_result = required_version(baseline~, delta=minor_delta())
    if minor_result.major != 0 || minor_result.minor != 5 || minor_result.patch != 3 {
      fail(
        "expected 0.5.3 for a Minor delta on 0.5.2, got \{minor_result.major}.\{minor_result.minor}.\{minor_result.patch}",
      )
    }
    let major_result = required_version(baseline~, delta=major_delta())
    if major_result.major != 0 || major_result.minor != 6 || major_result.patch != 0 {
      fail(
        "expected 0.6.0 for a Major delta on 0.5.2, got \{major_result.major}.\{major_result.minor}.\{major_result.patch}",
      )
    }
    let patch_result = required_version(baseline~, delta=patch_delta())
    if patch_result.major != 0 || patch_result.minor != 5 || patch_result.patch != 2 {
      fail(
        "expected 0.5.2 unchanged for a Patch delta, got \{patch_result.major}.\{patch_result.minor}.\{patch_result.patch}",
      )
    }
  } catch {
    _ => fail("failed to build one of the three fixture deltas")
  }
}

///|
test "verdict reports Sufficient when declared meets or exceeds the requirement" {
  try {
    let baseline = Version::{ major: 1, minor: 2, patch: 3 }
    let delta = minor_delta()
    match verdict(baseline~, declared=Version::{ major: 1, minor: 3, patch: 0 }, delta~) {
      Sufficient(_) => ()
      Insufficient(_) => fail("expected Sufficient when declared exactly meets 1.3.0")
    }
    match verdict(baseline~, declared=Version::{ major: 2, minor: 0, patch: 0 }, delta~) {
      Sufficient(_) => ()
      Insufficient(_) => fail("expected Sufficient when declared (2.0.0) exceeds 1.3.0")
    }
  } catch {
    _ => fail("failed to build a Minor-level fixture delta")
  }
}

///|
test "verdict reports Insufficient with the exact required and declared versions" {
  try {
    let baseline = Version::{ major: 1, minor: 2, patch: 3 }
    let delta = major_delta()
    let declared = Version::{ major: 1, minor: 3, patch: 0 }
    match verdict(baseline~, declared~, delta~) {
      Insufficient(required~, declared=got_declared) => {
        if required.major != 2 || required.minor != 0 || required.patch != 0 {
          fail(
            "expected required 2.0.0, got \{required.major}.\{required.minor}.\{required.patch}",
          )
        }
        if got_declared.major != 1 || got_declared.minor != 3 || got_declared.patch != 0 {
          fail(
            "expected declared 1.3.0 echoed back, got \{got_declared.major}.\{got_declared.minor}.\{got_declared.patch}",
          )
        }
      }
      Sufficient(_) => fail("expected Insufficient: declared 1.3.0 does not cover a Major delta")
    }
  } catch {
    _ => fail("failed to build a Major-level fixture delta")
  }
}
