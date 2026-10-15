# frozen_string_literal: true

require 'ffi'

class Voikko
  # The C functions, bound by the versioned soname: the bare +libvoikko.so+ ships only with
  # +libvoikko-dev+. A missing library re-raises +LoadError+, so a caller that makes the gem
  # optional still rescues it, with the packages to install appended.
  #
  # Its own file, required by {Voikko.new} and {Voikko.library_version} rather than by
  # +voikko.rb+, so {Voikko::Analysis} and {Voikko::Morpheme} work where libvoikko is not
  # installed. A failed load leaves the file unloaded, so the next call raises again.
  module Lib
    extend FFI::Library

    begin
      ffi_lib 'libvoikko.so.1'
    rescue LoadError => e
      raise LoadError, "#{e.message}\nlibvoikko is not installed: apt install libvoikko1 voikko-fi"
    end

    attach_function :voikkoGetVersion, [], :string
    attach_function :voikkoInit, %i[pointer string string], :pointer
    attach_function :voikkoTerminate, [:pointer], :void
    attach_function :voikkoAnalyzeWordCstr, %i[pointer string], :pointer
    attach_function :voikko_free_mor_analysis, [:pointer], :void
    attach_function :voikko_mor_analysis_keys, [:pointer], :pointer
    attach_function :voikko_mor_analysis_value_cstr, %i[pointer pointer], :pointer
    attach_function :voikko_free_mor_analysis_value_cstr, [:pointer], :void
  end
  private_constant :Lib
end
