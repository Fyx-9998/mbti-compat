///| Both tests share the same minimal fixture pair (a package that has one
/// function in `with_foo` and doesn't in `without_foo`) -- proven syntax
/// already exercised by `inverse_and_noise_wbtest.mbt`'s "add/remove" case,
/// reused here rather than inventing a new fixture shape. `compare(old=
/// with_foo, new=without_foo)` therefore always produces exactly one
/// change: MAJOR `sym-removed` on symbol `foo` in package `test/report`.

///| `render_text` includes the required-bump header, the change/waived
/// summary line, and the one expected change's package name and rule id.
/// Checked with `String::contains` rather than an exact full-string match --
/// this pins the format's essential content without over-constraining
/// incidental spacing choices that might reasonably change later.
test "render_text reports the required bump, the summary, and the change" {
  let failures : Array[String] = []
  try {
    let with_foo = @ingest.of_mbti_source(
      "package \"test/report\"\n\npub fn foo() -> Unit\n",
      name="report",
    )
    let without_foo = @ingest.of_mbti_source(
      "package \"test/report\"\n",
      name="report",
    )
    let delta = @compare.compare(old=with_foo, new=without_foo)
    let text = render_text(delta, color=false)
    if !(text.contains("Required version bump: MAJOR")) {
      failures.push(
        "expected the header to report a MAJOR required bump, got:\n\{text}",
      )
    }
    if !(text.contains("1 change(s), 0 waived")) {
      failures.push(
        "expected the summary line to report 1 change and 0 waived, got:\n\{text}",
      )
    }
    if !(text.contains("test/report")) {
      failures.push("expected the package name to appear in the rendered text")
    }
    if !(text.contains("sym-removed")) {
      failures.push("expected the sym-removed rule id to appear in the rendered text")
    }
  } catch {
    _ => failures.push("failed to parse a hand-crafted report fixture")
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}

///| `render_text(color=true)` wraps the header's level word in the expected
/// ANSI red (MAJOR) escape codes, and `color=false` never does -- a direct
/// check on the one color path this package implements.
test "render_text applies ANSI color only when asked" {
  let failures : Array[String] = []
  try {
    let with_foo = @ingest.of_mbti_source(
      "package \"test/report\"\n\npub fn foo() -> Unit\n",
      name="report",
    )
    let without_foo = @ingest.of_mbti_source(
      "package \"test/report\"\n",
      name="report",
    )
    let delta = @compare.compare(old=with_foo, new=without_foo)
    let plain = render_text(delta, color=false)
    let colored = render_text(delta, color=true)
    if plain.contains("\u{1b}[") {
      failures.push("expected no ANSI escape codes when color=false")
    }
    if !(colored.contains("\u{1b}[31m")) {
      failures.push("expected a red ANSI escape code for a MAJOR level when color=true")
    }
    if !(colored.contains("\u{1b}[0m")) {
      failures.push("expected an ANSI reset code when color=true")
    }
  } catch {
    _ => failures.push("failed to parse a hand-crafted report fixture")
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}

///| `render_json` produces exactly the expected structural JSON for the same
/// single-change fixture, checked with `Json`'s own `==` (structural
/// equality, `pub impl Eq for Json` in `moonbitlang/core/builtin`) rather
/// than a stringified comparison -- sidesteps depending on `Map`'s internal
/// key iteration order, which this project has no proof is stable.
test "render_json matches the expected structure for a single change" {
  let failures : Array[String] = []
  try {
    let with_foo = @ingest.of_mbti_source(
      "package \"test/report\"\n\npub fn foo() -> Unit\n",
      name="report",
    )
    let without_foo = @ingest.of_mbti_source(
      "package \"test/report\"\n",
      name="report",
    )
    let delta = @compare.compare(old=with_foo, new=without_foo)
    let expected : Json = Json::object(
      {
        "level": Json::string("MAJOR"),
        "changes": Json::array([
          Json::object(
            {
              "level": Json::string("MAJOR"),
              "rule": Json::string("sym-removed"),
              "package_name": Json::string("test/report"),
              "symbol": Json::string("foo"),
              "detail": Json::string("symbol removed"),
              "old_span": Json::null(),
              "new_span": Json::null(),
              "waived": Json::boolean(false),
            },
          ),
        ]),
      },
    )
    let actual = render_json(delta)
    if actual != expected {
      failures.push("render_json output did not match the expected structure")
    }
  } catch {
    _ => failures.push("failed to parse a hand-crafted report fixture")
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}

///| `render_json`'s output is empty-diff, not just non-crashing, when
/// nothing changed -- `Delta`'s own reflexivity guarantee (already proven at
/// the `compare` level by `properties_wbtest.mbt`'s corpus test) should
/// carry through the rendering layer unchanged.
test "render_json renders an empty delta as zero changes and Patch" {
  let failures : Array[String] = []
  try {
    let surface = @ingest.of_mbti_source(
      "package \"test/report\"\n\npub fn foo() -> Unit\n",
      name="report",
    )
    let delta = @compare.compare(old=surface, new=surface)
    let expected : Json = Json::object(
      { "level": Json::string("PATCH"), "changes": Json::array([]) },
    )
    let actual = render_json(delta)
    if actual != expected {
      failures.push("expected an empty delta to render as {\"level\": \"PATCH\", \"changes\": []}")
    }
  } catch {
    _ => failures.push("failed to parse a hand-crafted report fixture")
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}
