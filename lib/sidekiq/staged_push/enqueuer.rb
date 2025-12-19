# frozen_string_literal: true

require "sidekiq/staged_push/enqueuer/process_batch"

module Sidekiq
  module StagedPush
    class Enqueuer
      def initialize(_config)
        @done = false
      end

      def start
        @thread = Thread.new(&method(:process))
      end

      def stop
        @done = true
      end

      private

      def process
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
    end
  end
end
