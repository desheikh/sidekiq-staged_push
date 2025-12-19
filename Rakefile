# frozen_string_literal: true

require "bundler/setup"

APP_RAKEFILE = File.expand_path("spec/dummy/Rakefile", __dir__)
Rake.load_rakefile "spec/dummy/Rakefile"

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec
