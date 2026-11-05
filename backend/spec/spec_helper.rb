# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
require_relative "../config/boot"

module TestSupport
  module_function

  # A fresh, migrated and seeded in-memory database.
  def database
    db = Infrastructure::Persistence::Database.connect(":memory:")
    Infrastructure::Persistence::Database.migrate!(db)
    Infrastructure::Persistence::CatalogSeeder.new(db).seed_file(Container::SEED_FILE)
    db
  end

  # The real catalog from db/seeds/catalog.yml, loaded once. Domain specs use
  # it so they exercise the actual business rules, not a hand-built copy.
  def catalog
    @catalog ||= Infrastructure::Persistence::SequelCatalogRepository.new(database).load
  end

  # Catalog repository stub for application specs.
  StaticCatalogRepository = Struct.new(:catalog) do
    def load = catalog
  end

  # Deterministic clock: each call is one second after the previous one.
  def ticking_clock(start = Time.utc(2026, 1, 1))
    t = start
    -> { t += 1 }
  end
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
