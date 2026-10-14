# The `Voikko` class: the gem's first public API

The first binding is morphological analysis: hand libvoikko a word, get back
its analyses as Ruby values. The first caller is pikuri
(`pikuri/design/ideas/multilingual-stemming.md` on Codeberg: a `stemmer:`
duck mapping a word to its dictionary forms), but per **Knows no caller** the
API is generic and pikuri's adapter lives on pikuri's side.

The libvoikko facts behind it are in `design/research.md`; the handle's
threading, lifecycle and input checks are already decided (`D_handle_mutex`,
`D_handle_lifecycle`, `D_input_checks`). The shape below is agreed; nothing
is implemented yet.

## The API

```ruby
# frozen_string_literal: true

class Voikko                                  # was `module Voikko`
  VERSION = '0.1.0'

  class Error < StandardError; end            # libvoikko said no: init failed, terminated

  # One analysis: libvoikko's attributes, frozen Hash{String => String}.
  Analysis = Data.define(:attributes)
  class Analysis                              # reopened: a constant inside `Data.define do` lands on Voikko
    KEYS = {                                  # libvoikko's closed key enum, all 21
      'BASEFORM' => :base_form, 'CLASS' => :word_class, 'COMPARISON' => :comparison,
      'FOCUS' => :focus, 'FSTOUTPUT' => :fst_output, 'KYSYMYSLIITE' => :kysymysliite,
      'MALAGA_VAPAA_JALKIOSA' => :malaga_vapaa_jalkiosa, 'MOOD' => :mood,
      'NEGATIVE' => :negative, 'NUMBER' => :number, 'PARTICIPLE' => :participle,
      'PERSON' => :person, 'POSSESSIVE' => :possessive,
      'POSSIBLE_GEOGRAPHICAL_NAME' => :possible_geographical_name,
      'REQUIRE_FOLLOWING_VERB' => :require_following_verb, 'SIJAMUOTO' => :sijamuoto,
      'STRUCTURE' => :structure, 'TENSE' => :tense, 'WEIGHT' => :weight,
      'WORDBASES' => :word_bases, 'WORDIDS' => :word_ids
    }.freeze
    KEYS.each { |key, reader| define_method(reader) { attributes[key] } }  # String or nil

    def [](key) = attributes[key]             # analysis['SIJAMUOTO'] #=> "ulkoolento"
    def to_h    = attributes                  # overrides Data#to_h's {attributes: {...}}
  end

  def self.library_version = ...              # voikkoGetVersion, "4.3.3"

  def self.open(language:, path: nil)         # yields a new Voikko, terminates it after the block
  def initialize(language:, path: nil)        # raises Voikko::Error naming `voikko-fi`

  def analyze(word)    = ...                  # Array<Analysis>, [] for an unknown word
  def base_forms(word) = ...                  # Array<String>, uniq, libvoikko's order
  def terminate        = ...                  # idempotent; later calls raise Error
  def terminated?      = ...
end
```

```ruby
Voikko.open(language: 'fi') do |voikko|
  kadulla = voikko.analyze('kadulla').first
  kadulla.base_form                           #=> "katu"
  kadulla.sijamuoto                           #=> "ulkoolento"
  kadulla.tense                               #=> nil, a noun has none
  voikko.base_forms('voi')                    #=> ["voida", "voi"]
  voikko.base_forms('HELSINGISSÄ')            #=> ["Helsinki"]
end
```

## The whys, for the yardoc

- **`Voikko`, not `Voikko::Analyzer`:** libvoikko also spells, hyphenates
  and checks grammar, and an `Analyzer` passed around a caller's code loses
  its `Voikko::` prefix and reads as any analyser. A `Voikko::Voikko` inside
  the module stutters. Upstream's Python and Java bindings name the class
  `Voikko` too.
- **`language:` is required:** voikko-fi is the only dictionary anyone
  installs, but libvoikko serves other languages, and the keyword costs one
  word at the single call site.
- **A reader for each of the 21 keys:** no key is common to every
  morphology backend, but the key set is a closed enum in libvoikko
  (`R_analysis_backends`). So the readers mirror libvoikko rather than a
  guess, and each returns `nil` where the backend or the word class has no
  such attribute. Names are the key in snake_case, untranslated (`sijamuoto`,
  not `case`), except `CLASS` → `word_class`, since `#class` is taken.
  Values stay libvoikko's strings: `negative` is `"true"`, `"false"` or
  `"both"`, `person` is `"1"`. `#[]` and `#to_h` reach any key a later
  libvoikko adds.
- **`FSTOUTPUT` passes through** like any other key: it is noise to most
  callers, but dropping it would be a policy (**A thin binding**).
- **`base_forms` keeps the dictionary's case** (`"Helsinki"`): downcasing is
  a stemming policy, and the caller's.
- **`Voikko.open { }` beside `Voikko.new`**, the way `File.open` sits beside
  `File.new`: the block form is where `#terminate` runs without the caller
  remembering it (`D_handle_lifecycle`).
- **A missing `libvoikko.so.1` re-raises `LoadError`** at `require`, with
  `apt install libvoikko1 voikko-fi` appended to the message: a `LoadError`
  keeps `rescue LoadError` working for a caller that makes the gem optional,
  and **Errors are loud** wants the packages named.

## Left out until asked

Spelling, suggestions, hyphenation, grammar checking, `voikko_list_dicts`
and `voikkoGetAttributeValues`. Their methods would sit on this class
(`#spell`, `#suggest`, `#hyphenate`), which is why it is not named
`Analyzer`.

## Done when

The class and its specs run against the real library in CI, the yardoc
carries the whys above, a CHANGELOG line names the new API, and this file is
deleted.
