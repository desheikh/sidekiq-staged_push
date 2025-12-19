# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require File.expand_path("dummy/config/environment", __dir__)
require "rspec/rails"
require "sidekiq/staged_push"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.use_transactional_fixtures = true

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  ActiveRecord::Migration.maintain_test_schema!
end
