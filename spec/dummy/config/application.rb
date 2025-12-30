# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"

Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    # Set Rails root to the dummy app directory
    config.root = File.expand_path("..", __dir__)

    config.load_defaults Rails::VERSION::STRING.to_f

    config.eager_load = false

    # Don't generate system test files
    config.generators.system_tests = nil

    # Use Sidekiq for ActiveJob
    config.active_job.queue_adapter = :sidekiq
  end
end
