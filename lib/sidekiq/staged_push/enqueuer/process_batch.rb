# frozen_string_literal: true

require "sidekiq/staged_push/staged_job"
require "sidekiq/client"

module Sidekiq
  module StagedPush
    class Enqueuer
      class ProcessBatch
        BATCH_SIZE = 500

        def call
          StagedJob.transaction do
            jobs = StagedJob.
                   order(:id).
                   limit(BATCH_SIZE).
                   lock("FOR UPDATE SKIP LOCKED").
                   pluck(:id, :payload)

            return 0 if jobs.empty?

            job_ids = jobs.map(&:first)
            StagedJob.where(id: job_ids).delete_all

            push_to_redis(jobs)

            jobs.size
          end
        end

        private

        def push_to_redis(jobs)
          client = Sidekiq::Client.new
          jobs.each { |(_, payload)| client.push(payload) }
        end
      end
    end
  end
end
