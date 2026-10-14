# ruby-voikko

Ruby bindings for [libvoikko](https://voikko.puimula.org/), the Finnish morphological analyser
that also powers Finnish spellchecking in LibreOffice. The gem is pure Ruby and calls the
system's `libvoikko` through FFI; the library and its Finnish dictionary come from your
distro's packages.

## Requirements

- Linux with `libvoikko1` and the Finnish dictionary `voikko-fi`:

  ```sh
  sudo apt install libvoikko1 voikko-fi
  ```

- Ruby 3.2 or newer.

## Installation

```ruby
gem 'voikko'
```

## Usage

```ruby
require 'voikko'

Voikko.open(language: 'fi') do |voikko|
  kadulla = voikko.analyze('kadulla').first
  kadulla.base_form                 #=> "katu"
  kadulla.sijamuoto                 #=> "ulkoolento"
  voikko.base_forms('voi')          #=> ["voida", "voi"]
  voikko.base_forms('HELSINGISSÄ')  #=> ["Helsinki"]
end
```

`Voikko.open` terminates the handle after the block; `Voikko.new` leaves that to `#terminate`.

## License

MIT, see [LICENSE](LICENSE). The gem ships no Voikko code or data: libvoikko
(MPL 1.1 / GPL 2+ / LGPL 2.1+) and `voikko-fi` (GPL 2) are installed and licensed separately
by your distro.
