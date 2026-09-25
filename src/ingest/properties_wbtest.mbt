///| Only needed in this test file: `ingest.mbt` itself stays fully qualified
/// w.r.t. `@surface` (several of its variant names deliberately mirror
/// upstream `moonbitlang/parser` names one-for-one, so ambiguity there is
/// worth avoiding), but this file needs to pattern-match `Symbol::Unsupported`
/// directly to check the corpus for unmodelled constructs, so it brings just
/// that one type in.
using @surface { type Symbol }

///| Gate 2's corpus-level correctness checks, run once over the full real
/// `moonbitlang/core` corpus (`core_corpus`, see `core_corpus_wbtest.mbt`):
/// every file must parse without diagnostics, must produce zero
/// `Symbol::Unsupported` entries (`ingest`'s conservative fallback for
/// constructs it doesn't yet model -- real, previously-unseen upstream text
/// is exactly what would expose a modelling gap that hand-written test cases
/// never would), `compare(s, s)` must be empty (Gate 2's reflexivity
/// property), and it must come out identical across two independent runs
/// (determinism). All four checks share one pass over the corpus so a single
/// `moon test` reports every failure found, not just the first one hit.
test "moonbitlang/core corpus: parses clean, fully modelled, reflexive, deterministic" {
  let failures : Array[String] = []
  if core_corpus.length() != 79 {
    failures.push(
      "corpus size drifted: expected 79 embedded files, found \{core_corpus.length()}",
    )
  }
  core_corpus.each(fn(entry) {
    let (name, src) = entry
    try {
      let surface = of_mbti_source(src, name~)
      surface.symbols.each(fn(id, sym) {
        match sym {
          Unsupported(raw~, ..) =>
            failures.push(
              "\{name}: symbol \{id.0} was not fully modelled by ingest (raw: \{raw})",
            )
          _ => ()
        }
      })
      let delta1 = @compare.compare(old=surface, new=surface)
      if delta1.changes.length() != 0 {
        failures.push(
          "\{name}: compare(s, s) was not empty (\{delta1.changes.length()} change(s)) -- reflexivity violated",
        )
      }
      let delta2 = @compare.compare(old=surface, new=surface)
      if delta1 != delta2 {
        failures.push("\{name}: compare(s, s) was not deterministic across two runs")
      }
    } catch {
      _ => failures.push("\{name}: failed to parse a real, previously-published .mbti file")
    }
  })
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}
