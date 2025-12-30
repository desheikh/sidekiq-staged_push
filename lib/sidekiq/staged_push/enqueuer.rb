# frozen_string_literal: true

require "securerandom"
require "sidekiq/component"
require "sidekiq/staged_push/enqueuer/process_batch"

module Sidekiq
  module StagedPush
    class Enqueuer
      include Sidekiq::Component

      POLL_INTERVAL = 0.5
      ERROR_RETRY_INTERVAL = 1
      SLOT_RETRY_INTERVAL = 30
      SLOT_KEY_PREFIX = "staged_push:enqueuer:slot"

      def initialize(config)
        @done = false
        @config = config
        @identity = "#{Socket.gethostname}:#{::Process.pid}:#{SecureRandom.hex(6)}"
        @client = Sidekiq::Client.new(config: @config)
        @processor = ProcessBatch.new(@client)
        @slot_key = nil
      end

      def start
        @slot_thread = Thread.new(&method(:acquire_slot_and_process))
      end

      def stop
        @done = true
        release_slot
      end

      private

      def acquire_slot_and_process
        until @done
          @slot_key = claim_slot
          if @slot_key
            logger.debug "StagedPush::Enqueuer: Claimed slot #{@slot_key}"
            @heartbeat_thread = Thread.new(&method(:maintain_slot))
            process
            return
          end

          logger.debug "StagedPush::Enqueuer: No slot available, retrying in #{SLOT_RETRY_INTERVAL}s"
          sleep SLOT_RETRY_INTERVAL
        end
      end

      def claim_slot
        Sidekiq::StagedPush.configuration.max_enqueuer_slots.times do |i|
          key = "#{SLOT_KEY_PREFIX}:#{i}"
          acquired = redis do |conn|
            conn.set(key, @identity, nx: true, ex: Sidekiq::StagedPush.configuration.slot_ttl)
          end
          return key if acquired
        end
        nil
      end

      def maintain_slot
        interval = Sidekiq::StagedPush.configuration.slot_ttl / 2
        until @done
          begin
            redis { |conn| conn.expire(@slot_key, Sidekiq::StagedPush.configuration.slot_ttl) }
            sleep interval
          rescue StandardError => e
            logger.error "Error maintaining slot: #{e.class} - #{e.message}"
            sleep ERROR_RETRY_INTERVAL
          end
        end
      end

      def release_slot
        return unless @slot_key

        redis do |conn|
          # Only delete if we still own it
          current_owner = conn.get(@slot_key)
          conn.del(@slot_key) if current_owner == @identity
        end
        logger.debug "StagedPush::Enqueuer: Released slot #{@slot_key}"
        @slot_key = nil
      end

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
