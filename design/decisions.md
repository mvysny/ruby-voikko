# Decisions

Why this project is the way it is and not otherwise — FAQ-shaped: each entry is a question and
its current answer. Rewrite the answer when it changes; delete the entry when nobody asks any
more. An entry is earned by what it would cost to reverse — half the code base — or by research
the next person would otherwise redo (cited as its `R_`). Not an entry: windows → panels
"because that's the trend", this red over that red, `get_foo` over `is_foo?`, the testing library,
the CI host, a version bump — a comment at the site of the choice, or nothing; nothing about
`design/` itself. Cite by slug, `D_<slug>`, never by position; `grep '^## D_' design/decisions.md`
is the index. The first entry is the ruler: every later one trims to its length — which is how
long this file gets, so keep it short. When you have written an entry, re-read it against the one
above, open the doc comments it touches and cut what they already say, then cut the fat.

---

## D_ffi_distro_lib — Why FFI to the distro's libvoikko rather than a C extension or bundled sources?

The gem ships Ruby only. It binds `libvoikko.so.1` (Debian/Ubuntu `libvoikko1`) through the
`ffi` gem on the first `Voikko.new`, by that versioned name, since the bare `libvoikko.so` comes only with
`libvoikko-dev` (`R_library_files`); libvoikko finds the dictionary on its own (`voikko-fi`, under
`/usr/lib/voikko/`). The binding needs only a handful of calls: init and terminate a handle,
analyse a word, read one attribute of an analysis, free the result. Why not a C extension: it
needs `libvoikko-dev` and a compiler at `gem install` and a rebuild for every Ruby version,
to wrap five functions that `ffi`, already precompiled for common platforms, can bind
directly. Why not bundle libvoikko's sources, the way `ruby-stemmer` bundles libstemmer: the
gem would then own libvoikko's security fixes and would have to match the dictionary format
version (the `5` in that path) that the distro already keeps in step with its library. Shipping
no Voikko code also keeps the gem MIT. The cost: macOS needs libvoikko from elsewhere, and a
missing library shows up at the first `Voikko.new`, not at install, so the load error names the
packages. Why not bind at `require`, which would fail earlier: `Analysis` and `Morpheme` are
plain Ruby, and binding late lets a caller's own tests build them on a machine without
libvoikko, such as a CI that never opens a handle.

## D_handle_mutex — Why does each handle lock itself rather than leave threads to the caller?

libvoikko's handle is not reentrant: two threads in one handle get wrong analyses, with no
crash and no error (`R_handle_threads`). So every call into a handle, `#close` included,
runs under that handle's own `Mutex`, as upstream's Java binding does with `synchronized`
(`R_official_bindings`). Why not document "one handle per thread", as the Python binding does:
the failure is silent, so a caller who shares one handle across a server's threads finds out
from bad data, if ever. Why not rely on the GVL, which FFI holds by default and which kept the
shared-handle test clean: JRuby and TruffleRuby have no GVL. The cost is one uncontended lock
per word; a caller who wants analyses in parallel opens a handle per thread, which libvoikko
supports.

## D_handle_lifecycle — Why both an explicit `#close` and a GC finalizer?

A handle holds native memory Ruby's GC cannot see (`R_handle_threads`: about 0.5 MB each), so
it is released two ways, the pair both upstream bindings use (`R_official_bindings`): an
`FFI::AutoPointer` whose release calls `voikkoTerminate`, and `#close`, which frees it at
once; any later call raises. Why not `#close` alone: a forgotten call leaks until the
process exits. Why not the finalizer alone: a caller opening handles in a loop runs ahead of a
GC that sees none of that memory. The finalizer may run on another thread, which is safe: it
runs only once the handle is unreachable, and closing one handle while others analyse is
clean. Analyses are copied into Ruby strings before the C array is freed, so no Ruby value
outlives the C memory it came from.

## D_input_checks — Why raise on a NUL byte or bad encoding, yet return no analyses for an empty or over-long word?

`analyze` raises `ArgumentError` when the word holds a NUL byte or cannot be read as UTF-8,
and returns `[]` when libvoikko returns NULL for an empty word or one over 255 bytes
(`R_cstr_input`). A NUL truncates the word inside libvoikko and analyses the prefix, a wrong
answer; bad encoding means the caller passed bytes where text was meant. Both are caller
bugs, and **Errors are loud**. Why not return `[]` for a NUL, as both upstream bindings do: it
hides that bug. An empty or over-long string is text that is no word, which a tokeniser over
arbitrary input (URLs, base64) meets routinely; raising would make every caller rescue. NFD
input is passed through unnormalised and gets no analyses; normalising is the caller's, per
**A thin binding**. Why `Cstr` over `Ucs4`: Ruby strings are already UTF-8, and the 255-byte
limit cuts only words past any real Finnish word.
