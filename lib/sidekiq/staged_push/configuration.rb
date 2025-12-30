# frozen_string_literal: true

module Sidekiq
  module StagedPush
    class Configuration
      attr_accessor :base_class, :batch_size, :max_enqueuer_slots, :slot_ttl

      def initialize
        @base_class = "ActiveRecord::Base"
        @batch_size = 500
        @max_enqueuer_slots = 5
        @slot_ttl = 30
      end
    end

    class << self
      def configuration
        @configuration ||= Configuration.new
      end
    end
  end
end
