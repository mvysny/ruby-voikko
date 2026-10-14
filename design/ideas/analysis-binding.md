# The first binding: morphological analysis

The first API: hand libvoikko a word and get back its analyses as Ruby
values. That is what pikuri needs (`pikuri/design/ideas/multilingual-stemming.md`
on Codeberg: a `stemmer:` duck that maps a word to its dictionary forms), but
per the **Knows no caller** promise the API is generic, and the
pikuri adapter lives on pikuri's side.

Investigate first, then implement. Each finding verified against the installed
library graduates to `design/research.md` as an `R_` with provenance (the
file does not exist yet; the `design-docs` skill's template creates it).
Choices that are expensive to reverse go to `design/decisions.md` as a `D_`.

## Prerequisite

The host does not have libvoikko installed yet:
`sudo apt install libvoikko1 voikko-fi` (Ubuntu ships 4.3.3 and 2.5).
`libvoikko-dev` only adds the header, which is useful for reading the API but
not needed at runtime.

## What `voikko.h` (4.3.3) says: read, not yet run

- `voikkoInit(const char **error, const char *langcode, const char *path)` →
  a handle, or NULL with `*error` set. `langcode` is a BCP 47 tag; `path` is an
  extra dictionary directory, searched first, or NULL.
- `voikkoTerminate(handle)`.
- `voikkoAnalyzeWordCstr(handle, word)` → a NULL-terminated array of
  `voikko_mor_analysis *`; free it with `voikko_free_mor_analysis(array)`.
- `voikko_mor_analysis_keys(analysis)` → a `const char **`, freed together
  with the analysis array.
- `voikko_mor_analysis_value_cstr(analysis, key)` → a `char *` the **caller
  must free** with `voikko_free_mor_analysis_value_cstr`. This differs from
  the `_ucs4` variant, whose value is freed with the array: easy to leak.
- `voikkoGetVersion()`.
- The dictionary installed by `voikko-fi` lives at
  `/usr/lib/voikko/5/mor-standard/` (`mor.vfst`, `autocorr.vfst`,
  `index.txt`).

## Open questions

- **`Q_attribute_keys`:** which keys does an analysis actually carry, and in
  what format? Expected at least `BASEFORM`, `WORDBASES`, `STRUCTURE`,
  `CLASS`, `SIJAMUOTO`, `NUMBER`. Verify on real words:
  - an inflected noun with a consonant change: *kadulla*, *kadun*, *katu*;
  - a compound: *tietokone*;
  - an ambiguous word with several analyses;
  - an unknown word (a name, a typo), expecting an empty array;
  - a capitalised word and an all-caps one.
  How `WORDBASES` encodes compound parts (`+tieto(tieto)+kone(kone)`?)
  decides whether the gem parses it or hands it over raw (**A thin binding**:
  lean raw, plus at most a documented accessor).
- **`Q_init_langcode`:** does `"fi"` work, or is `"fi_FI"` or `"fi-x-…"`
  needed? What does the error string look like when the dictionary is
  missing? It becomes the load error's message, which must name the packages
  (the **Errors are loud** convention).
- **`Q_thread_safety`:** is one handle safe to use from two threads? Check the
  libvoikko sources, docs or mailing list. If it is not, choose between a
  `Monitor` inside the gem and documenting "one handle per thread". This is a
  `D_` either way.
- **`Q_handle_lifecycle`:** how does `voikkoTerminate` get called? An explicit
  `#terminate` / block form (`Voikko.open('fi') { |v| ... }`), a finalizer via
  `FFI::AutoPointer`, or both? AutoPointer frees at GC time, which may be on
  another thread; check this against `Q_thread_safety`.
- **`Q_api_shape`:** sketch: `Voikko::Analyzer.new(language: 'fi')`,
  `#analyze(word)` → `Array<Voikko::Analysis>` (a `Data.define` wrapping a
  frozen `Hash{String => String}`), plus `#base_forms(word)` →
  `Array<String>`, deduplicated. Is `Analyzer` the right noun, given that
  libvoikko also does spelling, hyphenation and grammar? Leave those out until
  asked for, but don't name the class in a way that rules them out.
- **`Q_encoding`:** input is UTF-8 via the `Cstr` variants. What happens with
  a non-UTF-8 or binary string? Raise in Ruby before the call, or trust
  libvoikko? Fuzzing a few nasty inputs (empty string, NUL byte, a
  10 000-character word) is cheap and lands as an `R_`.
- **`Q_library_name`:** `ffi_lib 'voikko'`, or `'libvoikko.so.1'`? The
  package listings show that `libvoikko1` ships only `libvoikko.so.1` →
  `libvoikko.so.1.16.3`; the unversioned `libvoikko.so` symlink comes from
  `libvoikko-dev`. So `ffi_lib 'voikko'` likely fails on a runtime-only
  install. Verify, then prefer the versioned name, with a fallback list for
  macOS (`libvoikko.1.dylib`).

## Done when

The prerequisite is installed; every `Q_` above is answered, its verified
facts are in `design/research.md` (`R_`) and its choices in
`design/decisions.md` (`D_`); the binding and specs run against the real
library in CI; and this file is deleted.
