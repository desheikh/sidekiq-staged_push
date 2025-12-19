# frozen_string_literal: true

class ExampleActiveJob < ApplicationJob
  def perform(message = nil)
    Rails.logger.info "[ExampleActiveJob] #{message}"
  end
end
