# frozen_string_literal: true

require_relative 'lib/voikko/version'

Gem::Specification.new do |spec|
  spec.name     = 'voikko'
  spec.version  = Voikko::VERSION
  spec.authors  = ['Martin Vysny']
  spec.email    = ['martin@vysny.me']
  spec.summary  = 'Ruby bindings for libvoikko, the Finnish morphological analyser, via FFI.'
  spec.homepage = 'https://github.com/mvysny/ruby-voikko'
  spec.license  = 'MIT'

  spec.required_ruby_version = '>= 3.3'

  spec.metadata = {
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/master/CHANGELOG.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'documentation_uri' => "https://rubydoc.info/gems/#{spec.name}",
    'rubygems_mfa_required' => 'true'
  }

  # Shown on rubygems.org; the gem cannot install these itself.
  spec.requirements = ['libvoikko1 and voikko-fi from your distro: apt install libvoikko1 voikko-fi']

  spec.files = Dir['lib/**/*.rb'] + %w[README.md LICENSE CHANGELOG.md]

  # Binds the system's libvoikko at load time; see design/decisions.md D_ffi_distro_lib.
  spec.add_dependency 'ffi', '~> 1.17'
end
