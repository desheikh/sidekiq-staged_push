# frozen_string_literal: true

class CreateStagedPushJobs < ActiveRecord::Migration[7.2]
  def change
    create_table :sidekiq_staged_push_jobs do |t|
      t.json :payload, null: false
      t.timestamps
    end
  end
end

