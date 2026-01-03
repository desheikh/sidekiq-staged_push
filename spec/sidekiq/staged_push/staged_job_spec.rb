# frozen_string_literal: true

RSpec.describe Sidekiq::StagedPush::StagedJob do
  it "inherits from the configured base_class" do
    expect(described_class.superclass).to eq(Sidekiq::StagedPush.configuration.base_class.constantize)
  end

  it "defaults to ApplicationRecord" do
    expect(Sidekiq::StagedPush.configuration.base_class).to eq("ApplicationRecord")
  end

  it "inherits from ActiveRecord::Base" do
    expect(described_class.ancestors).to include(ActiveRecord::Base)
  end
end
