# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
Dir.glob('tasks/*.rake').each { |r| load r }

desc 'Everything CI runs: specs, then the doc-layer tripwires'
task check: %i[spec design_tripwires]

task default: :check
