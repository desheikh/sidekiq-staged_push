# frozen_string_literal: true

RSpec.describe Sidekiq::StagedPush::Enqueuer do
  let(:client) { instance_double(Sidekiq::Client) }
  let(:config) { Sidekiq.default_configuration }
  let(:logger) { instance_double(Sidekiq::Logger) }

  before do
    stub_const("#{described_class}::POLL_INTERVAL", 0.01)
    stub_const("#{described_class}::ERROR_RETRY_INTERVAL", 0.01)
    stub_const("#{described_class}::SLOT_RETRY_INTERVAL", 0.05)
    Sidekiq::StagedPush.configuration.slot_ttl = 2
    allow(Sidekiq::Client).to receive(:new).and_return(client)
    allow(config).to receive(:logger).and_return(logger)
    allow(logger).to receive(:debug)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)

    # Clear any existing slots
    Sidekiq.redis do |conn|
      keys = conn.keys("#{described_class::SLOT_KEY_PREFIX}:*")
      conn.del(*keys) if keys.any?
    end
  end

  after do
    Sidekiq::StagedPush.configuration.slot_ttl = 30
  end

  describe "#start and #stop" do
    it "processes jobs when started and stops processing when stopped" do
      allow(client).to receive(:send).with(:raw_push, anything)

      enqueuer = described_class.new(config)
      enqueuer.start

      job = Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [1] })
      sleep 0.05

      expect(Sidekiq::StagedPush::StagedJob.find_by(id: job.id)).to be_nil

      enqueuer.stop
      sleep 0.05

      job = Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [1] })
      sleep 0.05

      expect(Sidekiq::StagedPush::StagedJob.find_by(id: job.id)).to eq job
    end

    it "claims a slot on start and releases on stop" do
      allow(client).to receive(:send).with(:raw_push, anything)

      enqueuer = described_class.new(config)
      enqueuer.start
      sleep 0.05

      expect(logger).to have_received(:debug).with(/Claimed slot/)

      enqueuer.stop
      sleep 0.05

      expect(logger).to have_received(:debug).with(/Released slot/)
    end
  end

  describe "slot limiting" do
    it "limits the number of active enqueuers to max_enqueuer_slots" do
      Sidekiq::StagedPush.configuration.max_enqueuer_slots = 2
      allow(client).to receive(:send).with(:raw_push, anything)

      enqueuers = Array.new(4) { described_class.new(config) }
      enqueuers.each(&:start)
      sleep 0.05

      # Only 2 should have claimed slots
      expect(logger).to have_received(:debug).with(/Claimed slot/).twice
      expect(logger).to have_received(:debug).with(/No slot available/).twice

      enqueuers.each(&:stop)
    ensure
      Sidekiq::StagedPush.configuration.max_enqueuer_slots = 5
    end

    it "retries slot acquisition and claims when one becomes available" do
      Sidekiq::StagedPush.configuration.max_enqueuer_slots = 1
      allow(client).to receive(:send).with(:raw_push, anything)

      first_enqueuer = described_class.new(config)
      first_enqueuer.start
      sleep 0.02

      expect(logger).to have_received(:debug).with(/Claimed slot/).once

      second_enqueuer = described_class.new(config)
      second_enqueuer.start
      sleep 0.02

      expect(logger).to have_received(:debug).with(/No slot available, retrying/).once

      # Release first slot - second enqueuer should automatically claim it
      first_enqueuer.stop
      sleep 0.1

      expect(logger).to have_received(:debug).with(/Claimed slot/).twice

      second_enqueuer.stop
    ensure
      Sidekiq::StagedPush.configuration.max_enqueuer_slots = 5
    end
  end

  describe "error handling" do
    it "logs errors and continues processing" do
      call_count = 0
      allow(client).to receive(:send).with(:raw_push, anything) do
        call_count += 1
        raise StandardError, "Redis connection failed" if call_count == 1
      end

      enqueuer = described_class.new(config)
      enqueuer.start

      Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [1] })

      # Wait for error to be logged and retry to succeed
      sleep 0.1

      enqueuer.stop

      expect(logger).to have_received(:error).with(/StandardError.*Redis connection failed/)
      expect(Sidekiq::StagedPush::StagedJob.count).to eq(0)
    end

    it "does not crash the processing thread on errors" do
      error_count = 0
      allow(client).to receive(:send).with(:raw_push, anything) do
        error_count += 1
        raise StandardError, "Temporary error" if error_count <= 2
      end

      enqueuer = described_class.new(config)
      enqueuer.start

      Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [1] })

      # Wait for multiple retries
      sleep 0.1

      enqueuer.stop

      # Should have logged errors but eventually processed the job
      expect(logger).to have_received(:error).with(/Temporary error/).at_least(:twice)
      expect(Sidekiq::StagedPush::StagedJob.count).to eq(0)
    end
  end
end
