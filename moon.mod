name = "mbti-compat"
version = "0.1.0"
license = "Apache-2.0"
readme = "README.md"
description = "Public-interface (.mbti) diff, semver classification, and CI version gate for MoonBit packages."
keywords = ["mbti", "semver", "api-compatibility", "ci", "diff"]
supported_targets = "+native+wasm+wasm-gc+js"

// Warning 0079 (implicit_impl_as_method) fires on every `derive(Eq)` in this
// toolchain version, flagging that `equal`/`not_equal` are auto-promoted to
// regular methods -- a behavior slated for removal, not a defect in our code.
// Suppressed project-wide rather than adding a `pub extend Type with Eq::{...}`
// boilerplate line per type; revisit if/when a MoonBit release drops the
// auto-promotion (at which point this line should simply be deleted, not
// replaced).
warnings = "-79"

// NOTE (owner action needed before `moon publish`):
//   `name` above is unscoped for local development. Before publishing, change it to
//   "<your-mooncakes-namespace>/mbti-compat", and add a `repository` field pointing at
//   the actual repo URL.

// `moonbitlang/parser` and `moonbitlang/lexer` were added via the real `moon add`
// command (run by the project owner from the live toolchain), not hand-edited:
//   moon add moonbitlang/parser   -> added the parser entry below
//   moon add moonbitlang/lexer    -> added the lexer entry below
// `lexer` is a direct dependency (not just transitive-via-parser) because
// src/ingest imports "moonbitlang/lexer/basic" directly, for @basic.Location/
// Position -- moon requires the containing module of any directly-imported
// package to also be a direct dependency of this module, even when it's already
// pulled in transitively.
import {
  "moonbitlang/parser@0.4.0",
  "moonbitlang/lexer@0.4.0",
}
