# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "irb"
gem "pry"
gem "rake", "~> 13.0"

# Rails for dummy app
gem "puma"

rails_version = ENV.fetch("RAILS_VERSION", "8.1")
gem "rails", "~> #{rails_version}"

sidekiq_version = ENV.fetch("SIDEKIQ_VERSION", "8.0")
gem "sidekiq", "~> #{sidekiq_version}"

# Testing
gem "fuubar"
gem "pg"
gem "rspec-rails", "~> 7.0"

gem "rubocop"
gem "rubocop-factory_bot"
gem "rubocop-performance"
gem "rubocop-rails"
gem "rubocop-rake"
gem "rubocop-rspec_rails"
