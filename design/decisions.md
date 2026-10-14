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
`ffi` gem at load time, and libvoikko finds the dictionary on its own (`voikko-fi`, under
`/usr/lib/voikko/`). The binding needs only a handful of calls: init and terminate a handle,
analyse a word, read one attribute of an analysis, free the result. Why not a C extension: it
needs `libvoikko-dev` and a compiler at `gem install` and a rebuild for every Ruby version,
to wrap five functions that `ffi`, already precompiled for common platforms, can bind
directly. Why not bundle libvoikko's sources, the way `ruby-stemmer` bundles libstemmer: the
gem would then own libvoikko's security fixes and would have to match the dictionary format
version (the `5` in that path) that the distro already keeps in step with its library. Shipping
no Voikko code also keeps the gem MIT. The cost: macOS needs libvoikko from elsewhere, and a
missing library shows up at `require`, not at install, so the load error names the packages.
