# frozen_string_literal: true

RSpec.describe Sidekiq::StagedPush::StagedJob do
  describe "base_class configuration" do
    it "inherits from the configured base_class" do
      expect(described_class.superclass).to eq(Sidekiq::StagedPush.base_class)
    end

    it "defaults to ActiveRecord::Base" do
      expect(Sidekiq::StagedPush.configuration.base_class).to eq("ActiveRecord::Base")
    end

    it "inherits from ActiveRecord::Base" do
      expect(described_class.ancestors).to include(ActiveRecord::Base)
    end
  end
end
