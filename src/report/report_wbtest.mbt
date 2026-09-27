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

///| `render_markdown` includes a Markdown header naming the required bump,
/// the summary line, and one bullet naming the change's package, symbol,
/// rule id, and detail -- checked with `String::contains`, same reasoning as
/// the `render_text` test above.
test "render_markdown reports the required bump, the summary, and the change" {
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
    let md = render_markdown(delta)
    if !(md.contains("## API compatibility report")) {
      failures.push("expected a Markdown header, got:\n\{md}")
    }
    if !(md.contains("**Required version bump: MAJOR**")) {
      failures.push("expected the required-bump line to report MAJOR, got:\n\{md}")
    }
    if !(md.contains("1 change(s), 0 waived")) {
      failures.push(
        "expected the summary line to report 1 change and 0 waived, got:\n\{md}",
      )
    }
    if !(md.contains("`test/report`")) {
      failures.push("expected the package name, backtick-wrapped, to appear in the output")
    }
    if !(md.contains("`foo`")) {
      failures.push("expected the symbol name, backtick-wrapped, to appear in the output")
    }
    if !(md.contains("`sym-removed`")) {
      failures.push("expected the rule id, backtick-wrapped, to appear in the output")
    }
    if md.contains("*(waived)*") {
      failures.push("expected no waived marker for a non-waived change")
    }
  } catch {
    _ => failures.push("failed to parse a hand-crafted report fixture")
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}

///| `render_markdown` renders an empty delta with a PATCH required bump and
/// no bullet list at all (no changes to list) -- mirrors the `render_json`
/// empty-delta test above, extended to check that the "0 change(s)" summary
/// line appears and no bullet marker (`"- "`) does.
test "render_markdown renders an empty delta as zero changes and Patch, no bullets" {
  let failures : Array[String] = []
  try {
    let surface = @ingest.of_mbti_source(
      "package \"test/report\"\n\npub fn foo() -> Unit\n",
      name="report",
    )
    let delta = @compare.compare(old=surface, new=surface)
    let md = render_markdown(delta)
    if !(md.contains("**Required version bump: PATCH**")) {
      failures.push("expected the required-bump line to report PATCH, got:\n\{md}")
    }
    if !(md.contains("0 change(s), 0 waived")) {
      failures.push("expected the summary line to report 0 changes, got:\n\{md}")
    }
    if md.contains("- **") {
      failures.push("expected no bullet list for an empty delta, got:\n\{md}")
    }
  } catch {
    _ => failures.push("failed to parse a hand-crafted report fixture")
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}

///| A waived change's bullet carries the ` *(waived)*` marker -- mirrors
/// `render_text`'s own `[waived]` marker, and the same "waivers mark, never
/// delete" correctness requirement. Since M1/M2-so-far has no `policy::
/// Delta::apply` yet to actually produce a waived change from real input,
/// this test hand-builds a `Delta`/`Change` waived by construction --
/// `Change`'s fields are all `pub(all)`, so a direct struct literal is legal
/// here even though no other test in this project needed one before (every
/// other fixture goes through the real ingest+compare pipeline instead).
/// `RuleId`/`SymbolId` are fully qualified (`@compare.RuleId`/
/// `@surface.SymbolId`) rather than added to this package's shared
/// `using @compare {...}`/`using @surface {...}` blocks in `imports.mbt` --
/// same one-off reasoning `main.mbt`'s own `@compare.Level::Patch` already
/// uses, and `imports.mbt`'s own doc comment explicitly says `RuleId` is
/// left out of the `using` block to avoid an `unused_type_declaration`
/// warning elsewhere in this package.
test "render_markdown marks a waived change without dropping it" {
  let change : Change = {
    level: Major,
    rule: @compare.RuleId("sym-removed"),
    package_name: "test/report",
    symbol: @surface.SymbolId("foo"),
    detail: "symbol removed",
    old_span: None,
    new_span: None,
    waived: true,
  }
  let delta : Delta = { changes: [change] }
  let md = render_markdown(delta)
  let failures : Array[String] = []
  if !(md.contains("*(waived)*")) {
    failures.push("expected the waived marker to appear for a waived change, got:\n\{md}")
  }
  if !(md.contains("`sym-removed`")) {
    failures.push("expected the waived change's rule id to still appear, got:\n\{md}")
  }
  if !(md.contains("1 change(s), 1 waived")) {
    failures.push("expected the summary line to count the waived change, got:\n\{md}")
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
