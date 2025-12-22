# frozen_string_literal: true

RSpec.describe Sidekiq::StagedPush::Enqueuer::ProcessBatch do
  let(:client) { instance_double(Sidekiq::Client) }

  describe "#call" do
    it "bulk pushes jobs to Redis and removes from the database" do
      allow(client).to receive(:send).with(:raw_push, anything)

      first_job = Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [1] })
      second_job = Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [2] })

      described_class.new(client).call

      expect(client).to have_received(:send).with(:raw_push, [{ "args" => [1] }, { "args" => [2] }])
      expect(Sidekiq::StagedPush::StagedJob.where(id: [first_job.id, second_job.id])).to be_empty
    end

    it "returns the number of jobs processed" do
      allow(client).to receive(:send).with(:raw_push, anything)

      Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [1] })
      Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [2] })

      result = described_class.new(client).call

      expect(result).to eq 2
    end

    it "returns 0 when there are no jobs" do
      result = described_class.new(client).call

      expect(result).to eq 0
    end

    it "bulk pushes jobs in order by id" do
      allow(client).to receive(:send).with(:raw_push, anything)

      Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [1] })
      Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [2] })
      Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [3] })

      described_class.new(client).call

      expect(client).to have_received(:send).with(
        :raw_push,
        [{ "args" => [1] }, { "args" => [2] }, { "args" => [3] }],
      )
    end

    it "respects the batch size limit" do
      allow(client).to receive(:send).with(:raw_push, anything)

      stub_const("#{described_class}::BATCH_SIZE", 2)

      Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [1] })
      Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [2] })
      Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [3] })

      result = described_class.new(client).call

      expect(result).to eq 2
      expect(Sidekiq::StagedPush::StagedJob.count).to eq 1
    end

    context "when Redis push fails" do
      it "rolls back the transaction and keeps jobs in the database" do
        allow(client).to receive(:send).with(:raw_push, anything).and_raise(
          RedisClient::ConnectionError, "Connection refused"
        )

        Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [1] })
        Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [2] })

        expect { described_class.new(client).call }.to raise_error(RedisClient::ConnectionError)
        expect(Sidekiq::StagedPush::StagedJob.count).to eq 2
      end
    end

    context "with concurrent workers using SKIP LOCKED" do
      it "allows parallel processing of different jobs" do
        # Create jobs with proper payload structure (including queue for raw_push)
        Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [1], "queue" => "default" })
        Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [2], "queue" => "default" })
        Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [3], "queue" => "default" })
        Sidekiq::StagedPush::StagedJob.create!(payload: { "args" => [4], "queue" => "default" })

        stub_const("#{described_class}::BATCH_SIZE", 2)

        real_client = Sidekiq::Client.new

        # Simulate two concurrent workers
        results = []
        threads = Array.new(2) do
          Thread.new do
            results << described_class.new(real_client).call
          end
        end
        threads.each(&:join)

        # Both workers should have processed jobs
        expect(results.sum).to eq 4
        expect(Sidekiq::StagedPush::StagedJob.count).to eq 0
      end
    end
  end
end
