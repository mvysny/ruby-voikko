# frozen_string_literal: true

describe Voikko do
  around do |example|
    Voikko.open(language: 'fi') do |voikko|
      @voikko = voikko
      example.run
    end
  end

  it 'reports the library version' do
    assert_match(/\A\d+\.\d+/, Voikko.library_version)
  end

  describe '#analyze' do
    it 'reads a noun' do
      analyses = @voikko.analyze('kadulla')
      assert_equal 1, analyses.size
      kadulla = analyses.first
      assert_equal 'katu', kadulla.base_form
      assert_equal 'nimisana', kadulla.word_class
      assert_equal 'ulkoolento', kadulla.sijamuoto
      assert_equal 'singular', kadulla.number
      assert_nil kadulla.tense
    end

    it 'reads a verb' do
      sanoin = @voikko.analyze('sanoin').find { |a| a.base_form == 'sanoa' }
      assert_equal 'teonsana', sanoin.word_class
      assert_equal '1', sanoin.person
      assert_equal 'false', sanoin.negative
    end

    it 'reaches any key through [] and to_h' do
      kadulla = @voikko.analyze('kadulla').first
      assert_equal 'ulkoolento', kadulla['SIJAMUOTO']
      assert_nil kadulla['NO_SUCH_KEY']
      assert_equal kadulla.attributes, kadulla.to_h
      assert_equal 'katu', kadulla.to_h['BASEFORM']
      assert kadulla.to_h.key?('FSTOUTPUT')
    end

    it 'returns frozen UTF-8 strings' do
      attributes = @voikko.analyze('HELSINGISSÄ').first.to_h
      assert attributes.frozen?
      attributes.each do |key, value|
        assert key.frozen?
        assert value.frozen?
        assert_equal Encoding::UTF_8, value.encoding
        assert value.valid_encoding?
      end
    end

    it 'has a reader for every key it returns' do
      %w[kadulla sanoin en nopeasti onnellisuus Helsingissä kirjoittanut].each do |word|
        @voikko.analyze(word).each do |analysis|
          analysis.to_h.each_key { |key| assert Voikko::Analysis::KEYS.key?(key), key }
        end
      end
    end

    it 'returns every reading of an ambiguous word' do
      assert_equal 5, @voikko.analyze('alusta').size
    end

    it 'returns [] for an unknown word' do
      assert_equal [], @voikko.analyze('xyzzy')
    end

    it 'returns [] for an empty word and for one over 255 bytes' do
      assert_equal [], @voikko.analyze('')
      assert_equal [], @voikko.analyze('a' * 256)
    end

    it 'transcodes a word from another encoding' do
      assert_equal ['pää'], @voikko.analyze('pää'.encode(Encoding::ISO_8859_1)).map(&:base_form).uniq
    end

    it 'raises on a NUL byte' do
      assert_raises(ArgumentError) { @voikko.analyze("kis\0sa") }
    end

    it 'raises on bytes that are not UTF-8' do
      assert_raises(ArgumentError) { @voikko.analyze("p\xE4\xE4") }
      assert_raises(ArgumentError) { @voikko.analyze("p\xC3\xA4\xC3\xA4".b) }
    end
  end

  describe '#base_forms' do
    it 'dedups the base forms in libvoikko order' do
      assert_equal %w[voida voi], @voikko.base_forms('voi')
    end

    it "keeps the dictionary's case" do
      assert_equal ['Helsinki'], @voikko.base_forms('HELSINGISSÄ')
    end

    it 'returns [] for an unknown word' do
      assert_equal [], @voikko.base_forms('kisssa')
    end
  end

  describe 'lifecycle' do
    it 'raises Error naming voikko-fi for a language with no dictionary' do
      error = assert_raises(Voikko::Error) { Voikko.new(language: 'xx') }
      assert_includes error.message, 'voikko-fi'
      assert_includes error.message, 'Specified dictionary variant was not found'
    end

    it 'terminates after the block and returns its value' do
      handle = nil
      result = Voikko.open(language: 'fi') do |voikko|
        handle = voikko
        refute voikko.terminated?
        voikko.base_forms('kadulla')
      end
      assert_equal ['katu'], result
      assert handle.terminated?
    end

    it 'terminates even when the block raises' do
      handle = nil
      assert_raises(RuntimeError) do
        Voikko.open(language: 'fi') do |voikko|
          handle = voikko
          raise 'boom'
        end
      end
      assert handle.terminated?
    end

    it 'returns the open handle without a block' do
      voikko = Voikko.open(language: 'fi')
      assert_equal ['katu'], voikko.base_forms('kadulla')
    ensure
      voikko&.terminate
    end

    it 'terminates idempotently and raises on later calls' do
      voikko = Voikko.new(language: 'fi')
      voikko.terminate
      voikko.terminate
      assert voikko.terminated?
      assert_raises(Voikko::Error) { voikko.analyze('kadulla') }
      assert_raises(Voikko::Error) { voikko.base_forms('kadulla') }
    end

    it 'keeps analyses valid after terminate' do
      voikko = Voikko.new(language: 'fi')
      kadulla = voikko.analyze('kadulla').first
      voikko.terminate
      GC.start
      assert_equal 'katu', kadulla.base_form
    end
  end

  it 'gives the single-threaded answers when threads share one handle' do
    words = %w[kadulla alusta voi sanoin Helsingissä onnellisuus tietokone linja-autossa]
    expected = words.to_h { |word| [word, @voikko.analyze(word)] }
    mismatches = Array.new(8) do
      Thread.new do
        Array.new(250) { words.sample }.count { |word| @voikko.analyze(word) != expected[word] }
      end
    end.sum(&:value)
    assert_equal 0, mismatches
  end
end
