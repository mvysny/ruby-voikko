# Changelog

## [Unreleased]

- Ruby 3.3 is now the minimum (3.2 is end-of-life); upgrade Ruby to keep using the gem.
- `Voikko` (now a class, not a module) opens a libvoikko handle whose `#analyze` returns `Voikko::Analysis` values and `#base_forms` a word's dictionary forms.
