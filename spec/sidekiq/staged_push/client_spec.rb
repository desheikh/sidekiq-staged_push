# frozen_string_literal: true

class TestJob
  include Sidekiq::Job
end

RSpec.describe Sidekiq::StagedPush::Client do
  describe "#push" do
    it "saves the normalized job to the database" do
      client = described_class.new
      item = { "class" => TestJob, "args" => [11] }

      expect { client.push(item) }.
        to change(Sidekiq::StagedPush::StagedJob, :count).
        by(1)

      job = Sidekiq::StagedPush::StagedJob.last
      expect(job.payload).to include(
        "class" => "TestJob",
        "args" => [11],
        "queue" => "default",
        "retry" => true,
      )
      expect(job.payload["jid"]).to be_present
    end

    it "returns the job id" do
      client = described_class.new
      item = { "class" => TestJob, "args" => [11] }

      jid = client.push(item)

      expect(jid).to be_present
      expect(Sidekiq::StagedPush::StagedJob.last.payload["jid"]).to eq(jid)
    end

    it "invokes client middleware before persisting" do
      middleware_called = false
      received_payload = nil

      Sidekiq.configure_client do |config|
        config.client_middleware do |chain|
          chain.add(Class.new do
            define_method(:call) do |_job_class, job, _queue, _redis_pool, &block|
              middleware_called = true
              received_payload = job.dup
              block.call
            end
          end)
        end
      end

      client = described_class.new
      item = { "class" => TestJob, "args" => [11] }

      client.push(item)

      expect(middleware_called).to be true
      expect(received_payload).to include("class" => "TestJob", "args" => [11])
    ensure
      Sidekiq.configure_client do |config|
        config.client_middleware(&:clear)
      end
    end

    it "does not persist the job if middleware stops it" do
      Sidekiq.configure_client do |config|
        config.client_middleware do |chain|
          chain.add(Class.new do
            define_method(:call) do |_job_class, _job, _queue, _redis_pool|
              nil # Stop the job by not calling the block
            end
          end)
        end
      end

      client = described_class.new
      item = { "class" => TestJob, "args" => [11] }

      result = client.push(item)

      expect(result).to be_nil
      expect(Sidekiq::StagedPush::StagedJob.count).to eq(0)
    ensure
      Sidekiq.configure_client do |config|
        config.client_middleware(&:clear)
      end
    end

    it "persists custom properties injected by middleware" do
      Sidekiq.configure_client do |config|
        config.client_middleware do |chain|
          chain.add(Class.new do
            define_method(:call) do |_job_class, job, _queue, _redis_pool, &block|
              job["custom_property"] = "injected_value"
              job["trace_id"] = "abc123"
              block.call
            end
          end)
        end
      end

      client = described_class.new
      item = { "class" => TestJob, "args" => [11] }

      client.push(item)

      job = Sidekiq::StagedPush::StagedJob.last
      expect(job.payload).to include(
        "custom_property" => "injected_value",
        "trace_id" => "abc123",
      )
    ensure
      Sidekiq.configure_client do |config|
        config.client_middleware(&:clear)
      end
    end
  end

  describe "#push_bulk" do
    it "delegates to Sidekiq::Client without staging" do
      mock_redis_client = instance_double(Sidekiq::Client, push_bulk: nil)
      allow(Sidekiq::Client).to receive(:new).and_return(mock_redis_client)

      client = described_class.new
      first_item = { "class" => TestJob, "args" => [11] }
      second_item = { "class" => TestJob, "args" => [12] }

      expect { client.push_bulk([first_item, second_item]) }.
        not_to change(Sidekiq::StagedPush::StagedJob, :count)

      expect(mock_redis_client).to have_received(:push_bulk).with([first_item, second_item])
    end
  end
end
