# frozen_string_literal: true

require "sidekiq"
require "sidekiq/staged_push/client"
require "sidekiq/staged_push/enqueuer"
require "sidekiq/staged_push/version"

module Sidekiq
  module StagedPush
    DEFAULT_BATCH_SIZE = 500

    class << self
      attr_writer :batch_size

      def batch_size
        @batch_size || DEFAULT_BATCH_SIZE
      end
    end

    def self.enable!
      Sidekiq.default_job_options["client_class"] = Sidekiq::StagedPush::Client
      Sidekiq::JobUtil::TRANSIENT_ATTRIBUTES << "client_class"

      Sidekiq.configure_server do |config|
        enqueuer = Enqueuer.new(config)

        config.on(:startup) do
          enqueuer.start
        end
        config.on(:quiet) do
          enqueuer.stop
        end
      end
    end
  end
end
