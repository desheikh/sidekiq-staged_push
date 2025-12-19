# frozen_string_literal: true

class ExampleActiveJob < ActiveJob::Base
  self.queue_adapter = :sidekiq

  def perform(message = nil)
    Rails.logger.info "[ExampleActiveJob] #{message}"
  end
end
