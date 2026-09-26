///| `parse_cli` is pure (no `@env.args()`, no file I/O), so every case below
/// is a plain, synchronous `test { ... }` -- no `@async`/`@fs` fixture
/// scaffolding needed, unlike `main.mbt`'s own I/O-bound functions. Each
/// literal `Array[String]` is sliced with `[0:]` (an open-ended-upper-bound
/// slice starting at index 0) to get the `ArrayView[String]` `parse_cli`
/// expects -- the same slicing syntax `main.mbt`'s real-argv
/// `program_args()` uses with a literal `1` instead of `0`, ground-truthed
/// from `moonbitlang/parser/cmd/mq/main.mbt`.
test "parse_cli requires a subcommand" {
  let args : Array[String] = []
  match parse_cli(args[0:]) {
    Error(_) => ()
    _ => fail("expected an Error for an empty argument list")
  }
}

///|
test "parse_cli treats -h/--help as a request for help text, not an error" {
  let args : Array[String] = ["-h"]
  match parse_cli(args[0:]) {
    Help(_) => ()
    _ => fail("expected Help for -h")
  }
  let args2 : Array[String] = ["--help"]
  match parse_cli(args2[0:]) {
    Help(_) => ()
    _ => fail("expected Help for --help")
  }
}

///|
test "parse_cli rejects an unknown subcommand" {
  let args : Array[String] = ["frobnicate", "a.mbti", "b.mbti"]
  match parse_cli(args[0:]) {
    Error(_) => ()
    _ => fail("expected an Error for an unknown subcommand")
  }
}

///|
test "parse_cli parses check with two paths and json/color both off by default" {
  let args : Array[String] = ["check", "old.mbti", "new.mbti"]
  match parse_cli(args[0:]) {
    RunCheck(opts) => {
      if opts.old_path != "old.mbti" {
        fail("expected old_path to be \"old.mbti\", got \{opts.old_path}")
      }
      if opts.new_path != "new.mbti" {
        fail("expected new_path to be \"new.mbti\", got \{opts.new_path}")
      }
      if opts.json {
        fail("expected json to default to false")
      }
      if opts.color {
        fail("expected color to default to false")
      }
    }
    _ => fail("expected RunCheck")
  }
}

///|
test "parse_cli parses --json and --color in any position relative to the paths" {
  let args : Array[String] = ["check", "--json", "old.mbti", "--color", "new.mbti"]
  match parse_cli(args[0:]) {
    RunCheck(opts) => {
      if !opts.json {
        fail("expected json to be true")
      }
      if !opts.color {
        fail("expected color to be true")
      }
      if opts.old_path != "old.mbti" {
        fail("expected old_path to be \"old.mbti\", got \{opts.old_path}")
      }
      if opts.new_path != "new.mbti" {
        fail("expected new_path to be \"new.mbti\", got \{opts.new_path}")
      }
    }
    _ => fail("expected RunCheck")
  }
}

///|
test "parse_cli rejects a missing <new.mbti>" {
  let args : Array[String] = ["check", "old.mbti"]
  match parse_cli(args[0:]) {
    Error(_) => ()
    _ => fail("expected an Error when <new.mbti> is missing")
  }
}

///|
test "parse_cli rejects an unexpected extra positional argument" {
  let args : Array[String] = ["check", "old.mbti", "new.mbti", "extra.mbti"]
  match parse_cli(args[0:]) {
    Error(_) => ()
    _ => fail("expected an Error for an unexpected extra argument")
  }
}

///|
test "parse_cli rejects an unknown option" {
  let args : Array[String] = ["check", "--bogus", "old.mbti", "new.mbti"]
  match parse_cli(args[0:]) {
    Error(_) => ()
    _ => fail("expected an Error for an unknown option")
  }
}

///|
test "parse_cli treats -h inside check's arguments as help too" {
  let args : Array[String] = ["check", "old.mbti", "-h"]
  match parse_cli(args[0:]) {
    Help(_) => ()
    _ => fail("expected Help for -h appearing after check's subcommand")
  }
}
