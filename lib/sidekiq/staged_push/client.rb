# frozen_string_literal: true

require "sidekiq/client"
require "sidekiq/job_util"

module Sidekiq
  module StagedPush
    class Client
      include Sidekiq::JobUtil

      def initialize(*args, **kwargs)
        @redis_client = Sidekiq::Client.new(*args, **kwargs)
      end

      def push(item)
        normed = normalize_item(item)
        payload = @redis_client.middleware.invoke(item["class"], normed, normed["queue"], @redis_client.redis_pool) do
          normed
        end

        return unless payload

        verify_json(payload)
        Sidekiq::StagedPush::StagedJob.create!(payload: payload)
        payload["jid"]
      end

      # Same as for Sidekiq::TransactionAwareClient we don't provide
      # transactionality for push_bulk.
      delegate :push_bulk, to: :@redis_client
    end
  end
end
