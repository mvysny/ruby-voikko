# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'rspec/core'
require 'minitest'
require 'minitest/assertions'

require 'voikko'

RSpec.configure do |config|
  config.include Minitest::Assertions
  config.include(Module.new do
    attr_writer :assertions

    def assertions
      @assertions ||= 0
    end

    # Minitest::Assertions#skip shadows rspec's own and raises an exception
    # rspec reports as a *failure*; delegate back to rspec's pending
    # machinery. The trailing backtrace arg is minitest's signature.
    def skip(message = nil, _backtrace = nil)
      RSpec::Core::Pending.instance_method(:skip).bind_call(self, message)
    end
  end)
end
