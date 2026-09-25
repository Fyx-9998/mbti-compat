# mbti-compat

**Public-interface diff, semver classification, and CI version gate for MoonBit packages.**

`mbti-compat` compares two `.mbti` interface snapshots of a MoonBit package (the files `moon
info` generates from your public API) and tells you, precisely:

- what changed, symbol by symbol;
- whether each change is a **major**, **minor**, or **patch**-level break, using rules specific
  to MoonBit's surface language (labelled/optional parameters, `derive`, `pub(open)` traits,
  extensible vs. closed enums, error types, and more -- not just added/removed lines);
- the minimum version bump required, given your last published version;
- and, wired into CI, whether the version you're about to publish is actually high enough.

## Why this exists

mooncakes.io resolves dependencies with Minimal Version Selection (MVS): the highest version
requirement anywhere in the dependency graph wins for everyone. MVS quietly assumes "same major
line == compatible." Nothing today checks that assumption for MoonBit packages. A text diff of
two `.mbti` files can't tell a genuine break (a dropped `derive(Show)`, a narrowed return type)
from harmless noise (declaration reordering, an opaque struct becoming `type`). `mbti-compat` is
that missing check -- the MoonBit analogue of `cargo-semver-checks` (Rust), `Microsoft.DotNet.
ApiCompat.Tool` (.NET), or `go-apidiff` (Go).

`.mbti` parsing is delegated to `moonbitlang/parser`, which already has a well-scoped,
dependency-free `.mbti` AST and parser. `mbti-compat` owns the part that doesn't exist yet: the
comparison, the classification rules, the semver arithmetic, and the CI gate.

## Status

**Early scaffold.** The package layout and public API below are designed (see the project's
design brief); the comparison engine itself is not yet implemented. Nothing here should be
depended on yet.

## Package layout

```
src/surface/          normalized, comparable model of a package's public API   (pure, all backends)
src/ingest/            the only package depending on moonbitlang/parser        (pure, all backends)
src/compare/          change detection + major/minor/patch classification     (pure, all backends)
src/policy/           semver arithmetic, waivers, verdicts                    (pure, all backends)
src/report/           text / JSON / Markdown rendering                        (pure, all backends)
src/cmd/mbti-compat/  the CLI                                                 (native + wasm)
```

## License

Apache-2.0. See [LICENSE](./LICENSE).
