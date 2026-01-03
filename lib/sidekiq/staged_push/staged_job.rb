# frozen_string_literal: true

module Sidekiq
  module StagedPush
    class StagedJob < Sidekiq::StagedPush.configuration.base_class.constantize
      self.table_name = "sidekiq_staged_push_jobs"
    end
  end
end
