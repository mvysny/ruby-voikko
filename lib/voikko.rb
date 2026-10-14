# frozen_string_literal: true

require 'ffi'
require_relative 'voikko/version'

# A handle on libvoikko, the Finnish morphological analyser, bound through FFI to the system's
# +libvoikko.so.1+. Open one per language and ask it about words:
#
#   Voikko.open(language: 'fi') do |voikko|
#     kadulla = voikko.analyze('kadulla').first
#     kadulla.base_form               #=> "katu"
#     kadulla.sijamuoto               #=> "ulkoolento"
#     voikko.base_forms('voi')        #=> ["voida", "voi"]
#   end
#
# A handle holds about 0.5 MB of native memory that Ruby's GC cannot see: prefer {.open}, which
# closes it after the block, or call {#close} yourself. A forgotten handle is still freed by a
# finalizer once unreachable. After {#close}, every method but {#close} and {#closed?} raises
# {Error}.
#
# Named +Voikko+, not +Voikko::Analyzer+, because libvoikko also spells, hyphenates and checks
# grammar; those methods (+#spell+, +#suggest+, +#hyphenate+) would sit here, and are not bound
# yet. Upstream's Python and Java bindings name the class +Voikko+ too.
#
# == Thread-safety
#
# Thread-safe: every call into the handle runs under the handle's own mutex, since libvoikko's
# handle silently returns wrong analyses when two threads share it. Threads that want analyses
# in parallel open a handle each.
class Voikko
  # libvoikko refused: a dictionary failed to open, or the handle is already closed.
  class Error < StandardError; end

  # One reading of a word, as libvoikko gives it: a frozen +Hash{String => String}+ of its
  # attributes, with a reader for each key libvoikko defines.
  #
  #   analysis = voikko.analyze('kadulla').first
  #   analysis.base_form          #=> "katu"
  #   analysis.word_class         #=> "nimisana"
  #   analysis.tense              #=> nil, a noun has none
  #   analysis['SIJAMUOTO']       #=> "ulkoolento"
  #   analysis.to_h               #=> {"BASEFORM" => "katu", "CLASS" => "nimisana", ...}
  #
  # The readers are {KEYS}: libvoikko's closed key enum, each key in snake_case and untranslated
  # (+sijamuoto+, not +case+), except +CLASS+ → +word_class+ since +#class+ is taken. Each returns
  # +nil+ where the dictionary's backend or the word class has no such attribute; no key is
  # present for every backend. Values stay libvoikko's strings: +negative+ is +"true"+,
  # +"false"+ or +"both"+, +person+ is +"1"+. +FSTOUTPUT+ passes through like any other key.
  # {#[]} and {#to_h} reach a key a later libvoikko adds.
  #
  # @!attribute [r] attributes
  #   @return [Hash{String => String}] libvoikko's attributes, keyed by its upper-case names.
  Analysis = Data.define(:attributes)

  # Reopened rather than given as a +Data.define+ block: a constant inside that block would
  # land on {Voikko}.
  class Analysis
    # libvoikko's attribute keys, each mapped to the name of its reader on {Analysis}.
    # @return [Hash{String => Symbol}]
    KEYS = {
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

    KEYS.each { |key, reader| define_method(reader) { attributes[key] } }

    # @param key [String] a libvoikko key, upper case: +'SIJAMUOTO'+.
    # @return [String, nil] its value, or +nil+ when this analysis lacks it.
    def [](key) = attributes[key]

    # @return [Hash{String => String}] the attributes themselves, not +Data+'s
    #   +{attributes: {...}}+.
    def to_h = attributes
  end

  # The C functions, bound by the versioned soname: the bare +libvoikko.so+ ships only with
  # +libvoikko-dev+. A missing library re-raises +LoadError+, so a caller that makes the gem
  # optional still rescues it, with the packages to install appended.
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

  # @return [String] the system libvoikko's version: +"4.3.3"+.
  def self.library_version = Lib.voikkoGetVersion

  # Opens a handle, yields it and closes it after the block, the way +File.open+ sits beside
  # +File.new+: the block form is where {#close} runs without the caller remembering it.
  # Without a block it is {#initialize}.
  #
  #   Voikko.open(language: 'fi') { |voikko| voikko.base_forms('kadulla') }  #=> ["katu"]
  #
  # @param language [String] (see #initialize)
  # @param path [String, nil] (see #initialize)
  # @yieldparam voikko [Voikko] the open handle.
  # @return [Object, Voikko] the block's value, or the open handle when no block is given.
  # @raise [Error] (see #initialize)
  def self.open(language:, path: nil)
    voikko = new(language:, path:)
    return voikko unless block_given?

    begin
      yield voikko
    ensure
      voikko.close
    end
  end

  # Required although +voikko-fi+ is the only dictionary anyone installs: libvoikko serves other
  # languages, and the keyword costs one word at the single call site.
  #
  # @param language [String] a language tag: +'fi'+, +'fi-FI'+ or +'fi-x-standard'+.
  # @param path [String, nil] an extra directory to search for dictionaries, besides the system
  #   ones; a directory that does not exist is ignored.
  # @raise [Error] when no installed dictionary serves +language+; the message names +voikko-fi+.
  def initialize(language:, path: nil)
    error = FFI::MemoryPointer.new(:pointer)
    handle = Lib.voikkoInit(error, language, path)
    if handle.null?
      reason = error.read_pointer
      reason = reason.null? ? 'unknown error' : reason.read_string
      raise Error, "libvoikko has no dictionary for language #{language.inspect}: #{reason}. " \
                   'The Finnish one is the voikko-fi package: apt install voikko-fi'
    end
    @handle = FFI::AutoPointer.new(handle, Lib.method(:voikkoTerminate))
    @mutex = Mutex.new
  end

  # Every reading libvoikko finds for +word+, in its order. Case is ignored, and one word often
  # has several readings:
  #
  #   voikko.analyze('kadulla').map(&:base_form)   #=> ["katu"]
  #   voikko.analyze('voi').size                   #=> 5
  #   voikko.analyze('xyzzy')                      #=> []
  #
  # An empty word, or one over 255 bytes, is no word and gets +[]+ too. The word is not
  # Unicode-normalised: NFD input gets +[]+.
  #
  # @param word [String] one word, no surrounding whitespace; transcoded to UTF-8 if need be.
  # @return [Array<Analysis>] the readings; +[]+ for an unknown word.
  # @raise [ArgumentError] when +word+ holds a NUL byte, which libvoikko would silently cut the
  #   word at, or cannot be read as UTF-8.
  # @raise [Error] when this handle is closed.
  def analyze(word)
    word = utf8_word(word)
    with_handle do |handle|
      analyses = Lib.voikkoAnalyzeWordCstr(handle, word)
      next [] if analyses.null?

      begin
        null_terminated(analyses).map { |analysis| Analysis.new(attributes_of(analysis)) }
      ensure
        Lib.voikko_free_mor_analysis(analyses)
      end
    end
  end

  # The dictionary forms of +word+, one per distinct {Analysis#base_form}, in libvoikko's order.
  #
  #   voikko.base_forms('voi')            #=> ["voida", "voi"]
  #   voikko.base_forms('HELSINGISSÄ')    #=> ["Helsinki"]
  #
  # Keeps the dictionary's case: downcasing is a stemming policy, and the caller's.
  #
  # @param word [String] (see #analyze)
  # @return [Array<String>] the base forms; +[]+ for an unknown word.
  # @raise [ArgumentError] (see #analyze)
  # @raise [Error] (see #analyze)
  def base_forms(word) = analyze(word).filter_map(&:base_form).uniq

  # Frees the handle's native memory now rather than at GC. Idempotent. Named after Ruby's
  # +IO#close+, not libvoikko's +voikkoTerminate+, so it reads like every other resource.
  #
  # @return [void]
  def close
    @mutex.synchronize do
      @handle&.free
      @handle = nil
    end
  end

  # @return [Boolean] whether {#close} has run.
  def closed? = @mutex.synchronize { @handle.nil? }

  private

  def with_handle
    @mutex.synchronize do
      raise Error, 'this Voikko is closed' unless @handle

      yield @handle
    end
  end

  def utf8_word(word)
    begin
      utf8 = word.encode(Encoding::UTF_8)
    rescue EncodingError => e
      raise ArgumentError, "word cannot be read as UTF-8: #{e.message}"
    end
    raise ArgumentError, "word is not valid UTF-8: #{word.inspect}" unless utf8.valid_encoding?
    raise ArgumentError, "word holds a NUL byte: #{word.inspect}" if utf8.include?("\0")

    utf8
  end

  # @param array [FFI::Pointer] a NULL-terminated C array of pointers.
  # @return [Array<FFI::Pointer>] its elements, the NULL excluded.
  def null_terminated(array)
    elements = []
    offset = 0
    until (element = array.get_pointer(offset)).null?
      elements << element
      offset += FFI::Pointer.size
    end
    elements
  end

  # Copies one analysis into Ruby strings, so that nothing outlives the C array freed after it.
  #
  # @param analysis [FFI::Pointer] a +voikko_mor_analysis+.
  # @return [Hash{String => String}] its attributes, frozen.
  def attributes_of(analysis)
    null_terminated(Lib.voikko_mor_analysis_keys(analysis)).filter_map do |key|
      value = Lib.voikko_mor_analysis_value_cstr(analysis, key)
      next if value.null?

      begin
        [utf8_string(key), utf8_string(value)]
      ensure
        Lib.voikko_free_mor_analysis_value_cstr(value)
      end
    end.to_h.freeze
  end

  def utf8_string(pointer) = pointer.read_string.force_encoding(Encoding::UTF_8).freeze
end
