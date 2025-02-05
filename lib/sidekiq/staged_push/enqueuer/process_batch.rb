# frozen_string_literal: true

require "sidekiq/staged_push/staged_job"
require "sidekiq/client"

module Sidekiq
  module StagedPush
    class Enqueuer
      class ProcessBatch
        BATCH_SIZE = 500

        def call
          jobs = StagedJob.order(:id).limit(BATCH_SIZE).to_a

          return 0 if jobs.empty?

          client = Sidekiq::Client.new

          StagedJob.transaction do
            StagedJob.where(id: jobs.map(&:id)).delete_all
            jobs.each { |job| client.push(job.payload) }
          end

          jobs.size
        end
      end
    end
  end
end
