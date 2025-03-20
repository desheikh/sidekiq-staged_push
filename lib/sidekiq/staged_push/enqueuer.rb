# frozen_string_literal: true

require "sidekiq/component"
require "sidekiq/staged_push/enqueuer/process_batch"

module Sidekiq
  module StagedPush
    class Enqueuer
      include Sidekiq::Component

      def initialize(config)
        @done = false
        @config = config
      end

      def start
        @thread = Thread.new(&method(:process))
      end

      def stop
        @done = true
      end

      private

      def process
        StagedJob.with_advisory_lock!("sidekiq_staged_push", { timeout_seconds: 0 }) do
          until @done
            begin
              jobs_processed = ProcessBatch.new.call
              sleep 0.2 if jobs_processed.zero?
            rescue StandardError => e
              Sidekiq.logger.error "Error in StagedPush::Enqueuer: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
              sleep 1
            end
          end
        end
      rescue WithAdvisoryLock::FailedToAcquireLock
        sleep 30
        retry unless @done
      end
    end
  end
end
