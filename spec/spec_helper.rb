# frozen_string_literal: true

require "bundler/setup"
require "sidekiq/staged_push"
require "active_record"
require "rails/generators"
require "database_cleaner/active_record"

db_directory = Pathname.new(File.expand_path("../db/", File.dirname(__FILE__)))

ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  database: "sidekiq_staged_push_test",
  host: ENV.fetch("PGHOST", "localhost"),
  username: ENV.fetch("PGUSER", nil),
  password: ENV.fetch("PGPASSWORD", nil)
)

# Drop and recreate tables for a clean slate
ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS sidekiq_staged_push_jobs CASCADE")
ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS schema_migrations CASCADE")
ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS ar_internal_metadata CASCADE")

Rails::Generators.invoke("sidekiq:staged_push:install", ["--force"])
ActiveRecord::MigrationContext.new(db_directory.join("migrate")).migrate

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
  end

  config.around do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
