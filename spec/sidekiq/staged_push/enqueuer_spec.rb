# frozen_string_literal: true

RSpec.describe Sidekiq::StagedPush::Enqueuer do
  let(:client) { instance_double(Sidekiq::Client) }
  let(:config) { Sidekiq.default_configuration }

  before do
    stub_const("#{described_class}::POLL_INTERVAL", 0.01)
    stub_const("#{described_class}::ERROR_RETRY_INTERVAL", 0.01)
    allow(Sidekiq::Client).to receive(:new).and_return(client)
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
  end

  describe "error handling" do
    it "logs errors and continues processing" do
      logger = instance_double(Sidekiq::Logger)
      allow(config).to receive(:logger).and_return(logger)
      allow(logger).to receive(:error)

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
      logger = instance_double(Sidekiq::Logger)
      allow(config).to receive(:logger).and_return(logger)
      allow(logger).to receive(:error)

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
      expect(logger).to have_received(:error).at_least(:twice)
      expect(Sidekiq::StagedPush::StagedJob.count).to eq(0)
    end
  end
end
