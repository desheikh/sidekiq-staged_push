# frozen_string_literal: true

class ExampleJob
  include Sidekiq::Job

  def perform(message = nil)
    Rails.logger.info "[ExampleJob] #{message}"
  end
end
