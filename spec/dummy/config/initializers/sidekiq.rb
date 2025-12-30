# frozen_string_literal: true

require "sidekiq/rails"
require "sidekiq/staged_push"

Sidekiq::StagedPush.configure
