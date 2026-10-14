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

## API shape

`Voikko` becomes a class (today `lib/voikko/version.rb` opens it as a
module): `Voikko.new(language: 'fi')` is one libvoikko handle;
`#analyze(word)` → `Array<Voikko::Analysis>` (a `Data.define` wrapping a
frozen `Hash{String => String}`); `#base_forms(word)` → `Array<String>`,
deduplicated (*voi* repeats `voida` three times). Not `Voikko::Analyzer`:
libvoikko also spells, hyphenates and checks grammar, and an `Analyzer`
passed around a caller's code loses its `Voikko::` prefix and reads as any
analyser. Not a `Voikko::Voikko` class inside the module: it stutters.
Upstream's Python and Java bindings name the class `Voikko` too. The class's
yardoc carries this why once it exists.

## Done when

The binding and specs run against the real library in CI, and this file is
deleted.
