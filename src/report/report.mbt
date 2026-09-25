///| The word for a `Level`, used both as the "Required version bump: ..."
/// header and per-change label in `render_text`, and as the JSON `"level"`
/// string in `render_json`. Written as an explicit `match` rather than
/// interpolating the `Level` value directly (`\{level}`) -- `Level` only
/// derives `Debug` (not the deprecated `Show`), and no test anywhere in this
/// project has yet proven that a `derive(Debug)`-only enum interpolates
/// cleanly via `\{}` (see `gate3-decisions-and-plan.md`'s "not yet proven"
/// notes) -- this sidesteps the question entirely rather than gambling on it
/// in a file every future report format depends on.
fn level_word(level : Level) -> String {
  match level {
    Major => "MAJOR"
    Minor => "MINOR"
    Patch => "PATCH"
  }
}

///| ANSI SGR color codes for `render_text(color=true)`: red for MAJOR,
/// yellow for MINOR, no color at all for PATCH (nothing worth drawing the
/// eye to). `\u{1b}` (ESC, U+001B) is confirmed real MoonBit string-escape
/// syntax -- `moonbitlang/parser`'s own `lexer/regex.mbt` uses `\u{...}`
/// extensively for real, compiling Unicode code-point literals.
fn colorize(level : Level, text : String) -> String {
  let reset = "\u{1b}[0m"
  match level {
    Major => "\u{1b}[31m\{text}\{reset}"
    Minor => "\u{1b}[33m\{text}\{reset}"
    Patch => text
  }
}

///| Human-readable rendering of a `Delta`: a header line stating the overall
/// required version bump, a summary line stating how many changes were
/// found and how many are waived, then one line per change -- in
/// `delta.changes`'s already-deterministic order (`compare.mbt` sorts by
/// `(package_name, symbol, rule)`, so this function never re-sorts).
///
/// Deliberately walks `delta.changes`, not `delta.active_changes()`: a
/// waived change is marked (with a trailing `[waived]`), never dropped from
/// the report -- Gate 2's correctness requirement 8, "waivers mark, never
/// delete; the summary always states how many were waived." M1 has no
/// `policy` package yet, so every `waived` field is always `false` today
/// (`0 waived` in the summary line) -- expected, not a bug, until M2's
/// `Delta::apply` exists.
pub fn render_text(delta : Delta, color~ : Bool) -> String {
  let lines : Array[String] = []
  let level = delta.level()
  let level_label = if color {
    colorize(level, level_word(level))
  } else {
    level_word(level)
  }
  lines.push("Required version bump: \{level_label}")
  let total = delta.changes.length()
  let waived_count = total - delta.active_changes().length()
  lines.push("\{total} change(s), \{waived_count} waived")
  delta.changes.each(fn(c) {
    let label = if color {
      colorize(c.level, level_word(c.level))
    } else {
      level_word(c.level)
    }
    let waived_marker = if c.waived { " [waived]" } else { "" }
    lines.push(
      "\{label}  \{c.package_name}  \{c.symbol.0}  \{c.rule.0}  \{c.detail}\{waived_marker}",
    )
  })
  lines.join("\n")
}

///| `Span -> Json`: `{"start": ..., "end": ...}`, or `Json::null()` for the
/// `None` most changes carry today -- only `Symbol::Unsupported` has a real
/// span in the `surface` model as of M1 (documented gap, see `surface.mbt`
/// and `compare/types.mbt`'s own doc comments on `Change`).
fn span_to_json(span : Span?) -> Json {
  match span {
    None => Json::null()
    Some(s) =>
      Json::object(
        { "start": Json::number(s.start.to_double()), "end": Json::number(s.end.to_double()) },
      )
  }
}

///| One `Change -> Json` object, field for field.
fn change_to_json(c : Change) -> Json {
  Json::object(
    {
      "level": Json::string(level_word(c.level)),
      "rule": Json::string(c.rule.0),
      "package_name": Json::string(c.package_name),
      "symbol": Json::string(c.symbol.0),
      "detail": Json::string(c.detail),
      "old_span": span_to_json(c.old_span),
      "new_span": span_to_json(c.new_span),
      "waived": Json::boolean(c.waived),
    },
  )
}

///| `Delta -> Json`: `{"level": "...", "changes": [...]}`, every change from
/// `delta.changes` (not `active_changes()`) -- same "waivers mark, never
/// delete" reasoning as `render_text` above. The caller (eventually
/// `src/cmd/mbti-compat`) is responsible for `.stringify()`-ing this to
/// text; kept as a `Json` value here per Gate 2's design brief signature
/// (`pub fn render_json(Delta) -> Json`), not a pre-serialized `String`.
pub fn render_json(delta : Delta) -> Json {
  Json::object(
    {
      "level": Json::string(level_word(delta.level())),
      "changes": Json::array(delta.changes.map(fn(c) { change_to_json(c) })),
    },
  )
}
