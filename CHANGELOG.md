# Changelog

## [Unreleased]

- `Analysis#morphemes` cuts the word into `Voikko::Morpheme`s decoded from `STRUCTURE`, and `Analysis` now holds the analysed `word`, so a hand-built `Analysis.new(attributes)` becomes `Analysis.new(word, attributes)`.
- `Voikko#language` answers the language tag the handle was opened with.

## [0.1.0] - 2026-10-14

- Initial release: a `Voikko` handle on the system libvoikko (Ruby ≥ 3.3, Linux) whose `#analyze` returns `Voikko::Analysis` values and `#base_forms` a word's dictionary forms.
