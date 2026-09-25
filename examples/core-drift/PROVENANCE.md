# Provenance

Both `.mbti` files in this directory are the real, unmodified, machine-generated
public-interface snapshot (`// Generated using \`moon info\`, DON'T EDIT IT`) of
[`moonbitlang/core`](https://github.com/moonbitlang/core)'s `argparse` package
(Apache-2.0), taken verbatim from two real commits to that repository. Nothing
in either file has been hand-edited, trimmed, or reformatted.

| File | Commit | Date | Subject |
|---|---|---|---|
| `argparse-f8806e9.mbti` | `f8806e996196ab8c8adb97966fe00bb6315a3dcd` | 2026-06-15 | feat(buffer): add write bytes interpolation alias |
| `argparse-32b97837.mbti` | `32b9783701965b206090be345840b5f4a37484df` | 2026-09-15 | ci: rely on default borrow RC convention |

Neither commit's own subject line has anything to do with `argparse` -- these
are simply the two commits Gate 2 pinned as the "before" and "after" points of
a roughly three-month window over which `moonbitlang/core` naturally evolved.
The `argparse` package's own `pkg.generated.mbti` happened to change during
that window as an incidental side effect of ordinary upstream development, not
because either commit specifically targeted it -- which is exactly the point:
a real, unremarkable slice of a real package's history, not a change staged to
make a good demo.

## Exact commands used to obtain these files

Run against a real, public clone of `moonbitlang/core` -- no GitHub API, no
authentication, and no access to any private infrastructure:

```sh
git clone --filter=blob:none --no-checkout https://github.com/moonbitlang/core.git core
cd core
git show f8806e996196ab8c8adb97966fe00bb6315a3dcd:argparse/pkg.generated.mbti > argparse-f8806e9.mbti
git show 32b9783701965b206090be345840b5f4a37484df:argparse/pkg.generated.mbti > argparse-32b97837.mbti
```

(`--filter=blob:none --no-checkout` is a partial clone: it fetches the full
commit graph and tree objects up front, cheaply, then lazily fetches only the
file blobs actually requested by `git show` -- there is nothing project-specific
about it; a plain `git clone` followed by the same two `git show` commands
against the resulting full checkout produces byte-identical output.)

Both `git show <commit>:<path>` invocations read a blob directly out of git's
object store by its committed path and commit, which is what guarantees these
are the literal bytes GitHub stored for `argparse/pkg.generated.mbti` at each
of those two commits -- not a re-generation, not a reconstruction.

## Why `pkg.generated.mbti` specifically

`moonbitlang/core` commits the `moon info`-generated `.mbti` file for each of
its packages directly into the repository (see the `DON'T EDIT IT` header
inside each file) rather than generating it on demand, so it can be read
straight out of git history for any past commit without needing that commit's
own toolchain to regenerate it.
