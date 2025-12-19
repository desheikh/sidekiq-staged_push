# frozen_string_literal: true

require "sidekiq/staged_push/staged_job"
require "sidekiq/client"

module Sidekiq
  module StagedPush
    class Enqueuer
      class ProcessBatch
        BATCH_SIZE = 500

        def call
          jobs = StagedJob.order(:id).limit(BATCH_SIZE).pluck(:id, :payload)
          return 0 if jobs.empty?

          client = Sidekiq::Client.new
          job_ids = jobs.map(&:first)

          StagedJob.transaction do
            StagedJob.where(id: job_ids).delete_all
            jobs.each { |(_, payload)| client.push(payload) }
          end

          jobs.size
        end
      end
    end
  end
end
