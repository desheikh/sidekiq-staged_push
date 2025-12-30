# frozen_string_literal: true

module Sidekiq
  module StagedPush
    def self.base_class
      @base_class ||= configuration.base_class.constantize
    end

    def self.staged_job_class
      @staged_job_class ||= begin
        klass = Class.new(base_class) do
          self.table_name = "sidekiq_staged_push_jobs"
        end
        const_set(:StagedJob, klass)
        klass
      end
    end

    class << self
      def const_missing(name)
        if name == :StagedJob
          staged_job_class
        else
          super
        end
      end
    end
  end
end
