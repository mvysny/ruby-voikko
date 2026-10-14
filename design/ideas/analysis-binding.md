# The first binding: morphological analysis

The first API: hand libvoikko a word and get back its analyses as Ruby
values. That is what pikuri needs (`pikuri/design/ideas/multilingual-stemming.md`
on Codeberg: a `stemmer:` duck that maps a word to its dictionary forms), but
per the **Knows no caller** promise the API is generic, and the
pikuri adapter lives on pikuri's side.

## Settled

The investigation is done; its facts are in `design/research.md` and the
choices in `design/decisions.md`:

- attribute keys and values: `R_analysis_attributes`, `R_wordbases_format`
  (lean raw: `WORDBASES` is too irregular to parse);
- language tag and init error: `R_init_langcode` (`"fi"` works; the error
  names no package, so the gem adds `voikko-fi`);
- threads: `D_handle_mutex`; handle lifecycle: `D_handle_lifecycle`;
- input checks and `Cstr` over `Ucs4`: `D_input_checks`;
- library name: `D_ffi_distro_lib`, `R_library_files`; who frees what:
  `R_analysis_memory`.

## Open questions

- **`Q_api_shape`:** sketch: `Voikko::Analyzer.new(language: 'fi')`,
  `#analyze(word)` → `Array<Voikko::Analysis>` (a `Data.define` wrapping a
  frozen `Hash{String => String}`), plus `#base_forms(word)` →
  `Array<String>`, deduplicated (*voi* repeats `voida` three times). Is
  `Analyzer` the right noun, given that libvoikko also does spelling,
  hyphenation and grammar? Leave those out until asked for, but don't name
  the class in a way that rules them out; upstream's Python and Java bindings
  both call the handle class `Voikko`.
- **macOS library name:** the fallback after `libvoikko.so.1` and `voikko`
  (`libvoikko.1.dylib`?) is unverified; there is no Mac to check on.

## Done when

`Q_api_shape` is answered; the binding and specs run against the real
library in CI; and this file is deleted.
