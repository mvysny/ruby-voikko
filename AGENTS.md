# ruby-voikko — AGENTS.md

## What this is

Ruby bindings for [libvoikko](https://voikko.puimula.org/), the Finnish morphological analyser
that also powers Finnish spellchecking in LibreOffice. The gem is pure Ruby and calls the
system's `libvoikko` through FFI; the library and its Finnish dictionary come from your
distro's packages.

## Promises

- **The distro's libvoikko, nothing bundled.** The gem is Ruby over FFI; the library and its dictionaries come from the OS package manager. See `D_ffi_distro_lib`.
- **A thin binding.** It exposes what libvoikko computes; stemming policy, tokenization and caching are the caller's.
- **Knows no caller.** Nothing in the gem is shaped for one consumer (pikuri or any other); a caller adapts to its API, never the reverse.

## Design docs

| File | Owns | Loaded |
|---|---|---|
| `README.md` | the pitch, requirements, install | — |
| `AGENTS.md` (this) | promises, the module map, conventions, commands | every turn |
| `design/decisions.md` | why this and not that — `D_` entries, FAQ-shaped | lazy |
| `design/research.md` | what libvoikko and voikko-fi actually do — `R_` entries with provenance | lazy |
| `design/ideas/` | not yet decided — one file per idea, `ls` is the index, deleted on graduation | transient |
| yardoc (source headers) | what one symbol does, why it is shaped so | at the symbol |
| `CHANGELOG.md` | what changed and what you must do about it | — |

Every fact lives in exactly one of these; the others link to it.

## Module map

- `lib/voikko.rb` — the `Voikko` handle class, its `Analysis` value and the private FFI binding `Voikko::Lib`.

## Conventions

- **Ruby ≥ 3.2, plain classes, `ffi` the only runtime dependency.** `Data.define` value objects.
- **Linux only**; macOS and Windows are unsupported.
- **`# frozen_string_literal: true`** atop every Ruby file.
- **YARD on every public module/class/method**: concrete `@param` / `@return` types, `@raise` for expected exceptions, the local *why*.
- **Tests: rspec-core with minitest-style asserts.** `describe` / `it` but `assert_equal` / `assert` / `refute`; no RSpec matchers, no rspec-mocks.
- **Tests run against the real libvoikko**, never a stub of it; CI installs `libvoikko1` + `voikko-fi`.
- **Errors are loud.** A missing library or dictionary raises at load with the packages to install; a libvoikko error raises with its message.
- **Pre-1.0: break APIs freely**, with a CHANGELOG line carrying the migration.
- **A CHANGELOG entry is one sentence**, new work under `[Unreleased]`.

## Commands

- `bundle exec rake check` (also the default task) — specs, then `design_tripwires`; what CI runs on push and PR (`.github/workflows/ci.yml`).
- `bundle exec rspec spec/voikko_spec.rb:42` — one test.

## Skills this project follows

- **Yardoc is browsed standalone on rubydoc.info**, so each header carries the complete local what *and* why. The `writing-rdoc` skill has the rules.
- **An idea file is temporary:** it lives in `design/ideas/`, one per file, and graduation is not done until the file is gone and its nuggets are in their durable homes. The `ideas-folder` skill has the procedure.
- **This doc layer** — the loaded file, the lazy `design/` files, the tripwire — is the `design-docs` skill's shape.

## Maintenance of this file

Loaded every turn; cap 34 KB, a module's own `AGENTS.md` 10 KB. Over it, in this order:
delete what has no home — status, history, class lists, what the code already says; trim
each line to its fact plus one clause and send the explanation home — why →
`design/decisions.md`, how across symbols → `design/architecture.md`, how in one symbol →
its doc comment, what upstream does → `design/research.md`; only then a module's own
`AGENTS.md`, peripheral modules first, never the core. Never paraphrase a lazy entry into a
line here. `design/verify_design_tripwires.sh` checks the caps and the cites.
