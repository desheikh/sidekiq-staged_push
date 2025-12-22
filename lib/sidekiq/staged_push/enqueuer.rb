# frozen_string_literal: true

require "sidekiq/component"
require "sidekiq/staged_push/enqueuer/process_batch"

module Sidekiq
  module StagedPush
    class Enqueuer
      include Sidekiq::Component

      POLL_INTERVAL = 0.2
      ERROR_RETRY_INTERVAL = 1

      def initialize(config)
        @done = false
        @config = config
        @client = Sidekiq::Client.new(config: @config)
        @processor = ProcessBatch.new(@client)
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
            jobs_processed = @processor.call
            sleep POLL_INTERVAL if jobs_processed.zero?
          rescue StandardError => e
            logger.error "Error in StagedPush::Enqueuer: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
            sleep ERROR_RETRY_INTERVAL
          end
        end
      end
    end
  end
end
