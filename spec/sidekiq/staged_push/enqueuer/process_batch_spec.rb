# frozen_string_literal: true

RSpec.describe Sidekiq::StagedPush::Enqueuer::ProcessBatch do
  let(:client) { instance_double(Sidekiq::Client, push: nil) }

  before do
    allow(Sidekiq::Client).to receive(:new).and_return(client)
  end

  after do
    Sidekiq::StagedPush::StagedJob.delete_all
  end

  it "pushes jobs to Redis and removes from the database" do
    first_job = Sidekiq::StagedPush::StagedJob.create!(payload: { args: [1] })
    second_job = Sidekiq::StagedPush::StagedJob.create!(payload: { args: [2] })

    described_class.new.call

    expect(client).to have_received(:push).with("args" => [1])
    expect(client).to have_received(:push).with("args" => [2])
    expect(Sidekiq::StagedPush::StagedJob.where(id: [first_job.id, second_job.id])).to eq []
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
end
