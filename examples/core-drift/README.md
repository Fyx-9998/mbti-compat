# examples/core-drift

M1's first end-to-end demonstration (design brief, "First demonstration (M1,
useful alone)"): does `mbti-compat` actually separate one real break from the
noise a plain text diff shows, on a real package's real history -- not a
hand-crafted fixture?

## What's here

- `argparse-f8806e9.mbti` / `argparse-32b97837.mbti` -- the real,
  machine-generated public-interface snapshot of `moonbitlang/core/argparse`
  (Apache-2.0) at two real commits, three months apart. See `PROVENANCE.md`
  for exactly how these were obtained and why they can be trusted to be the
  literal bytes GitHub stored.
- `core_drift_wbtest.mbt` -- a test that feeds both files (embedded as string
  literals identical to the files above -- see that file's own doc comment
  for why) through `ingest`+`compare` and asserts the result.

`git diff --no-index argparse-f8806e9.mbti argparse-32b97837.mbti` is worth
running by hand once, to see what a plain text diff reports: mostly noise
(reformatted derive lists, a struct that became a `type` line), with the one
change that actually matters -- a dropped trait implementation -- looking no
more significant than anything else in the diff.

## What `mbti-compat` finds instead

Running `compare` over the two snapshots (`core_drift_wbtest.mbt`) produces
exactly 12 classified changes:

| Level | Rule | Symbol | What it means |
|---|---|---|---|
| PATCH | `opacity-unchanged` | `ArgGroup` | `pub struct ArgGroup { // private fields }` became `type ArgGroup` -- both spellings are equally opaque from outside the package, so this is not a real API change. |
| MINOR | `func-param-optional-added` | `Command::Command` | Gained a trailing `default_subcommand?` parameter -- existing callers are unaffected. |
| **MAJOR** | `derive-removed` | `FlagAction` | **Lost `derive(Show)`.** This is the change Gate 2 flagged as the one a text diff makes easy to miss: right next to it, `FlagAction` also gained explicit `equal`/`to_string` methods, so the diff *looks* like a like-for-like rewrite. It isn't -- code that relied on `FlagAction : Show` (e.g. via a generic function with a `Show` constraint) no longer compiles against the new version. |
| **MAJOR** | `derive-removed` | `OptionAction` | Loses `derive(Show)` the same way `FlagAction` does. Gate 2's design brief named only the `FlagAction` case as its illustrative example; the real diff contains this second, equally real MAJOR change too -- recorded here because this is real upstream history, not a curated fixture, and the tool should report what is actually there. |
| MINOR | `sym-added` | `FlagAction::equal`, `FlagAction::to_string`, `OptionAction::equal`, `OptionAction::to_string`, `ValueRange::equal`, `ValueRange::to_string`, `ValueSource::equal`, `ValueSource::to_string` | Eight new, backward-compatible methods (the explicit replacements for what `derive(Show)`/`derive(Eq)` used to generate). |

Overall required version bump: **MAJOR** -- correctly driven by the two real
`derive(Show)` removals, not hidden underneath the ten MINOR/PATCH changes
that outnumber them.

## Status

This demonstrates `ingest`+`compare` directly (M1 plan steps 3-5, already
verified against the real 79-file `moonbitlang/core` corpus and two more
correctness properties -- see `gate3-decisions-and-plan.md`). `src/report`
and enough of `src/cmd/mbti-compat` for `mbti-compat check
argparse-f8806e9.mbti argparse-32b97837.mbti` to print this same table from
the command line are the next milestone (M1 plan step 7) -- at that point
this directory's two vendored files become a real CLI smoke test as well as
a `moon test` one, exactly as the design brief's evaluator checklist expects.
