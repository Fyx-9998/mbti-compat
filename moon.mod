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
//
// `moonbitlang/async@0.22.4` was likewise added via a real `moon add
// moonbitlang/async`, run once src/cmd/mbti-compat started using its
// fs/stdio subpackages and an `async fn main` -- but that entry was
// captured LATE: the owner ran `moon add` locally in the PycharmProjects
// mirror to get real `moon check`/`moon test` passing for the original
// src/cmd/mbti-compat commits, and that moon.mod edit was never pulled back
// into this repo or pushed to GitHub, so the pushed git clone's moon.mod
// silently lacked it. Caught only when the owner's real `moon check`
// against the pushed clone failed with "Import moonbitlang/async@0.21.2
// exists in global environment, but its containing module is not imported
// by mbti-compat@0.1.0" (a different cached version number than the 0.22.4
// actually pinned here -- that line just reflects whatever else is in the
// global module cache, not what this project resolved). Lesson recorded in
// gate3-decisions-and-plan.md: an owner-run `moon add` changes moon.mod
// just like a source edit does, and must be synced back into this repo the
// same way, not left to only make the PycharmProjects mirror pass.
import {
  "moonbitlang/parser@0.4.0",
  "moonbitlang/lexer@0.4.0",
  "moonbitlang/async@0.22.4",
}
