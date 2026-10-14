# macOS support

The gem is Linux-only for now. macOS becomes supported when CI proves it, and
it looks testable:

- GitHub's macOS runners ship Homebrew, and Homebrew has a `libvoikko`
  formula (4.3.3 at the time of writing) with bottles for Apple silicon and
  Intel. The formula also fetches the `voikko-fi` 2.5 dictionary, compiles it
  and installs it under the Homebrew prefix, so `brew install libvoikko` is
  the whole prerequisite. Unverified: read from formulae.brew.sh and the
  formula source, not run.
- Unknown: the dylib's name (`libvoikko.1.dylib`?) and whether `ffi_lib`
  finds it at all. On Apple silicon the Homebrew prefix is `/opt/homebrew`,
  whose `lib/` is not on the default `dlopen` path, so the gem may need to try
  `$(brew --prefix)/lib` explicitly.
- Unknown: whether libvoikko finds the dictionary without a path argument
  (the formula configures the dictionary path at build time, so probably).

## Done when

A macOS job in `.github/workflows/ci.yml` runs the specs green; the
library-name fallback and any dictionary-path handling are in the code; the
**Linux only** convention in `AGENTS.md` and the README's requirements name
macOS; the facts found on the way are `R_` entries; and this file is deleted.
