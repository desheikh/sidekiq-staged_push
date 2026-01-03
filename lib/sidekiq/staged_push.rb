# frozen_string_literal: true

require "sidekiq"
require "active_record"

require_relative "staged_push/version"
require_relative "staged_push/configuration"
require_relative "staged_push/client"
require_relative "staged_push/enqueuer"

module Sidekiq
  module StagedPush
    class << self
      def configure
        yield(configuration) if block_given?

        # Defer loading StagedJob until after Rails has loaded so base_class is defined
        ::Rails.application.config.after_initialize do
          require_relative "staged_push/staged_job"
        end

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
end
