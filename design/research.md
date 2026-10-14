# Research — libvoikko and its Finnish dictionary (voikko-fi)

What the things we don't own actually do. About *them*, never us: a sentence starting "we chose"
is a `D_`. `## R_<slug> — <title>`, one claim per bullet, one provenance marker per claim —
**[docs]**, **[src]**, **[verified <date>, <version>]**, **[unverified]** (a hypothesis; a design
built on it says so). A claim is earned by its provenance, or by having cost real work to find
out. Checked against libvoikko 4.3.3 and voikko-fi 2.5 on Ubuntu 26.04, driven through the `ffi`
gem; a version-sensitive claim names the version it was seen on. Cite by slug, `R_<slug>`, never
by position; `grep '^## R_' design/research.md` is the index. The first entry is the ruler: every
later one trims to its length — which is how long this file gets, so keep it short. When you have
written an entry, re-read it against the one above and cut the fat — a marker already says where a
claim came from.

---

## R_handle_threads — a handle is not reentrant; separate handles are independent

- `voikko.h`: "A single handle should not be used simultaneously from multiple threads." The
  homepage and architecture page say nothing about threads. **[docs]**
- 8 threads sharing one handle, `voikkoAnalyzeWordCstr` attached `blocking: true` (GVL
  released), 16 000 analyses: about 15 000 differed from the single-threaded answer. No crash
  and no error — the results are just wrong. **[verified 2026-10-14, 4.3.3]**
- The same run with the GVL held, FFI's default: 0 mismatches over 3 runs; the GVL serialises
  the calls. **[verified 2026-10-14, 4.3.3]**
- 16 threads, each opening, using and terminating its own handles while the others analyse:
  0 mismatches and no crash over 3 runs. Opening or terminating one handle while another
  analyses is likewise clean. **[verified 2026-10-14, 4.3.3]**
- libvoikko 3.0 (2010) introduced the `VoikkoHandle` API as "thread safe", allowing an
  "unlimited number of dictionaries to be opened and used simultaneously"; the older int-handle
  API, still in `voikko_deprecated.h`, is "not completely thread safe". **[docs]**
- A handle costs about 0.5 MB of data, per the architecture page. **[docs]**

## R_official_bindings — how upstream's Python and Java bindings wrap the C API

- Python (`libvoikko.py`): `analyze` calls `voikkoAnalyzeWordUcs4`; no locking — "One instance
  should not be used simultaneously from multiple threads"; `__del__` calls `terminate()`, and
  any use after it raises `VoikkoException`. **[src]**
- Java (`Voikko.java`): `analyze` calls `voikkoAnalyzeWordCstr` and frees each value with
  `voikko_free_mor_analysis_value_cstr`; the methods are `synchronized` "so that, unlike the
  underlying C library, these objects can be safely used from multiple threads"; `finalize()`
  calls `terminate()`, and use after it throws. **[src]**
- Both check a word for a NUL character before the call and return an empty list of analyses;
  neither enforces a length limit. **[src]**
- Python loads `libvoikko.so.1` on Linux, never the unversioned name. **[src]**

## R_library_files — which package ships which file

- `libvoikko1` ships `libvoikko.so.1` → `libvoikko.so.1.16.3` under
  `/usr/lib/x86_64-linux-gnu/`; the unversioned `libvoikko.so` comes only from `libvoikko-dev`.
  **[verified 2026-10-14, `dpkg -L`, 4.3.3-1]**
- So `ffi_lib 'voikko'`, which resolves `libvoikko.so`, finds nothing on a runtime-only
  install; untested, since this host has `libvoikko-dev`. **[unverified]**
- `voikko-fi` installs `/usr/lib/voikko/5/mor-standard/` (`mor.vfst`, `autocorr.vfst`,
  `index.txt`); `index.txt` declares `Language: fi-x-standard` and `Morphology-Backend:
  finnishVfst`. **[verified 2026-10-14, voikko-fi 2.5]**

## R_init_langcode — `voikkoInit` language tags and its error

- `fi`, `fi_FI`, `fi-FI` and `fi-x-standard` all open the voikko-fi dictionary.
  **[verified 2026-10-14, 4.3.3]**
- A tag with no dictionary — `sv`, `xx`, `""`, `fi-x-nonexistent` — returns NULL with the
  error "Specified dictionary variant was not found", the same text whether the language or
  only the variant is missing; it names no package. **[verified 2026-10-14, 4.3.3]**
- An extra dictionary `path` that does not exist is ignored, not an error.
  **[verified 2026-10-14, 4.3.3]**
- `voikko_list_dicts(NULL)` lists one dictionary: language `fi`, variant `standard`, description
  "suomi (perussanasto)". **[verified 2026-10-14, 4.3.3]**

## R_analysis_attributes — what an analysis carries

- Every analysis seen has `BASEFORM`, `CLASS`, `FSTOUTPUT`, `STRUCTURE` and `WORDBASES`; by word
  class it adds `SIJAMUOTO`, `NUMBER`, `PERSON`, `MOOD`, `TENSE`, `NEGATIVE`, `COMPARISON`,
  `PARTICIPLE`, `POSSESSIVE`, `FOCUS`, `KYSYMYSLIITE`, `POSSIBLE_GEOGRAPHICAL_NAME`,
  `REQUIRE_FOLLOWING_VERB`. Every value is a string, `"1"` and `"true"` included; `WORDIDS`
  never appeared. **[verified 2026-10-14, voikko-fi 2.5]**
- `morphological-analysis.txt` calls keys and values "recommended (but not required)" and
  language-dependent, and marks `BASEFORM`, `WORDBASES` and `FSTOUTPUT` as produced only for
  "fullMorphology" — which the public C API evidently requests. No stability promise. **[docs]**
- `voikkoGetAttributeValues` lists the closed value sets (`CLASS`: 17 values, `SIJAMUOTO`: 16)
  and returns NULL for the open ones (`BASEFORM`, `WORDBASES`, `STRUCTURE`). Its `COMPARISON`
  list omits `positive`, which *nopeasti* returns. **[verified 2026-10-14, voikko-fi 2.5]**
- An unknown word (*kisssa*, *xyzzy*) gives an empty array, not NULL.
  **[verified 2026-10-14, 4.3.3]**
- Ambiguity is common, and repeats base forms: *alusta* gives 5 analyses (alku, alus, alunen,
  alusta, alustaa), *voi* gives 5 with `voida` three times, *kadun* gives katu and katua.
  **[verified 2026-10-14, voikko-fi 2.5]**
- Analysis ignores case: *Kadulla* and *KADULLA* analyse as *kadulla*. `STRUCTURE` (`=` starts a
  morpheme, `i`/`j` upper case, `p`/`q` lower) shows the dictionary form's case, not the input's:
  *HELSINGISSÄ* gives `=ipppppppppp`. **[verified 2026-10-14, voikko-fi 2.5]**

## R_analysis_backends — each dictionary picks a morphology backend, and each emits its own keys

- The keys are a closed C++ enum, `voikko_mor_analysis::Key`, of 21: the 18 seen in
  `R_analysis_attributes` plus `MALAGA_VAPAA_JALKIOSA`, `WEIGHT` and `WORDIDS`. A new key needs a
  libvoikko release. Same in 4.3.3 and master. **[src]**
- The dictionary picks the backend: a V5 `.vfst` dictionary (voikko-fi) gets `finnishVfst` unless
  its `index.txt` names another; a V3 `.zhfst` speller (Giellatekno's Northern Sami and others) gets
  `null`; a V4 dictionary gets `hfst`, and its loader is built only with vislcg3. **[src]**
- `finnishVfst` emits the keys of `R_analysis_attributes`; `hfst` only `BASEFORM` (the lemma before
  the first `+`) and `FSTOUTPUT` (the tags after it); `vfst`, built only with an experimental flag,
  only `FSTOUTPUT` and `WEIGHT`; `null` no analyses at all. `lttoolbox` would emit `CLASS`,
  `STRUCTURE` and `SIJAMUOTO` `none`, but calls an `addAttribute` overload `Analysis` no longer
  has. **[src]**
- No key is common to every backend: `BASEFORM` is missing from `vfst`, `CLASS` from `hfst` and
  `vfst`. Even `finnishVfst` adds `BASEFORM` and `CLASS` only when the transducer output yields
  them; `STRUCTURE`, `FSTOUTPUT` and `WORDBASES` it always adds, `WORDIDS` only when the dictionary
  carries word ids. **[src]**
- Ubuntu's `libvoikko1` links `libhfstospell` but not vislcg3, and the archive packages no voikko
  dictionary but `voikko-fi`; so on Ubuntu analysis is `finnishVfst`, and a hand-installed
  `.zhfst` speller analyses every word to an empty array.
  **[verified 2026-10-14, 4.3.3-1, `ldd` and `apt-cache search`; the `.zhfst` half from src]**

## R_wordbases_format — `WORDBASES` is not a regular compound split

- Upstream: parts joined by `+`, each part's base form in parentheses, a derivational suffix
  with `+` before its base — `+köyde(köysi)+n+veto(veto)`. **[docs]**
- Seen: `+tieto(tieto)+kone(kone)`; `+onne(onni)+llisu(+nen)+us(+us)` (*onnellisuus*);
  `+syö(syödä)+ty(+ty)` (*syöty*); a hyphen or a number is a part without parentheses —
  `+linja(linja)+-+auto(auto)`, `+2010+-+luku(luku)`. **[verified 2026-10-14, voikko-fi 2.5]**
- Not every compound part is listed: *kahdeksankymmentä* gives `+kahdeksan(kahdeksan)` alone.
  **[verified 2026-10-14, voikko-fi 2.5]**
- Compounding yields odd readings: *linja-autossa* also analyses as `linja-Autto`, `CLASS`
  `sukunimi`. **[verified 2026-10-14, voikko-fi 2.5]**

## R_cstr_input — what `voikkoAnalyzeWordCstr` does with awkward input

- It returns NULL, not an empty array, for an empty string, invalid UTF-8, Latin-1 bytes, and a
  word over 255 bytes. **[verified 2026-10-14, 4.3.3]**
- The limit counts bytes, not characters: 255 × `a` is analysed and 256 × `a` is NULL;
  *pää* × 51 (255 bytes) is analysed and × 52 is NULL. `LIBVOIKKO_MAX_WORD_CHARS` is 255.
  **[verified 2026-10-14, 4.3.3]**
- `voikkoAnalyzeWordUcs4` returns an empty array on the same inputs, never NULL, and does
  analyse *pää* × 52; both stop analysing long compounds past about 155 characters (*pää* × 53,
  *tietokone* × 28 give nothing). **[verified 2026-10-14, 4.3.3]**
- A NUL byte silently truncates the word: `"kis\0sa"` is analysed as `"kis"`.
  **[verified 2026-10-14, 4.3.3]**
- No Unicode normalisation: NFD *kadulla* gives an empty array. Emoji, an embedded space and a
  10 000-character string return without a crash. **[verified 2026-10-14, 4.3.3]**

## R_analysis_memory — who frees what

- `voikkoAnalyzeWordCstr` returns a NULL-terminated array, freed with
  `voikko_free_mor_analysis`; the key arrays from `voikko_mor_analysis_keys` go with it. **[docs]**
- A `voikko_mor_analysis_value_cstr` value is the caller's to free with
  `voikko_free_mor_analysis_value_cstr`; a `_ucs4` value is freed with the array. **[docs]**
