# frozen_string_literal: true

RSpec.describe Sidekiq::StagedPush::Enqueuer::ProcessBatch do
  let(:client) { instance_double(Sidekiq::Client, push: nil) }

  before do
    allow(Sidekiq::Client).to receive(:new).and_return(client)
  end

  describe "#call" do
    it "pushes jobs to Redis and removes from the database" do
      first_job = Sidekiq::StagedPush::StagedJob.create!(payload: { args: [1] })
      second_job = Sidekiq::StagedPush::StagedJob.create!(payload: { args: [2] })

      described_class.new.call

      expect(client).to have_received(:push).with("args" => [1])
      expect(client).to have_received(:push).with("args" => [2])
      expect(Sidekiq::StagedPush::StagedJob.where(id: [first_job.id, second_job.id])).to be_empty
    end

    it "returns the number of jobs processed" do
      Sidekiq::StagedPush::StagedJob.create!(payload: { args: [1] })
      Sidekiq::StagedPush::StagedJob.create!(payload: { args: [2] })

      result = described_class.new.call

      expect(result).to eq 2
    end

    it "returns 0 when there are no jobs" do
      result = described_class.new.call

      expect(result).to eq 0
    end

    it "processes jobs in order by id" do
      Sidekiq::StagedPush::StagedJob.create!(payload: { args: [1] })
      Sidekiq::StagedPush::StagedJob.create!(payload: { args: [2] })
      Sidekiq::StagedPush::StagedJob.create!(payload: { args: [3] })

      described_class.new.call

      expect(client).to have_received(:push).with("args" => [1]).ordered
      expect(client).to have_received(:push).with("args" => [2]).ordered
      expect(client).to have_received(:push).with("args" => [3]).ordered
    end

    it "respects the batch size limit" do
      stub_const("#{described_class}::BATCH_SIZE", 2)

      Sidekiq::StagedPush::StagedJob.create!(payload: { args: [1] })
      Sidekiq::StagedPush::StagedJob.create!(payload: { args: [2] })
      Sidekiq::StagedPush::StagedJob.create!(payload: { args: [3] })

      result = described_class.new.call

      expect(result).to eq 2
      expect(Sidekiq::StagedPush::StagedJob.count).to eq 1
    end

    context "when Redis push fails" do
      it "rolls back the transaction and keeps jobs in the database" do
        Sidekiq::StagedPush::StagedJob.create!(payload: { args: [1] })
        Sidekiq::StagedPush::StagedJob.create!(payload: { args: [2] })

        allow(client).to receive(:push).and_raise(RedisClient::ConnectionError, "Connection refused")

        expect { described_class.new.call }.to raise_error(RedisClient::ConnectionError)
        expect(Sidekiq::StagedPush::StagedJob.count).to eq 2
      end
    end

    context "with concurrent workers using SKIP LOCKED" do
      it "allows parallel processing of different jobs" do
        # Create jobs
        Sidekiq::StagedPush::StagedJob.create!(payload: { args: [1] })
        Sidekiq::StagedPush::StagedJob.create!(payload: { args: [2] })
        Sidekiq::StagedPush::StagedJob.create!(payload: { args: [3] })
        Sidekiq::StagedPush::StagedJob.create!(payload: { args: [4] })

        stub_const("#{described_class}::BATCH_SIZE", 2)

        # Simulate two concurrent workers
        results = []
        threads = Array.new(2) do
          Thread.new do
            results << described_class.new.call
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
