# frozen_string_literal: true

# Loads the application and defines the composition root. Requires are
# explicit and ordered by layer: domain has no dependencies, application
# depends on domain, infrastructure and http depend on both.

ROOT = File.expand_path("..", __dir__)
$LOAD_PATH.unshift(ROOT)

%w[
  app/domain/shared/money
  app/domain/errors
  app/domain/catalog/category
  app/domain/catalog/service
  app/domain/catalog/rules
  app/domain/catalog/service_catalog
  app/domain/catalog/catalog_repository
  app/domain/pricing/price_quote
  app/domain/pricing/discounts
  app/domain/pricing/pricing_engine
  app/domain/packaging/violation
  app/domain/packaging/selection_policy
  app/domain/packaging/package
  app/domain/packaging/package_repository

  app/application/errors
  app/application/catalog_queries
  app/application/package_service

  app/infrastructure/persistence/database
  app/infrastructure/persistence/catalog_seeder
  app/infrastructure/persistence/discount_rule_mapper
  app/infrastructure/persistence/sequel_catalog_repository
  app/infrastructure/persistence/sequel_package_repository
  app/infrastructure/persistence/in_memory_package_repository

  app/http/serializers
  app/http/api
].each { |path| require path }

# Wires concrete adapters into the use cases. The only place that knows
# which persistence implementation is in use.
class Container
  SEED_FILE = File.join(ROOT, "db/seeds/catalog.yml")

  def self.database_path
    ENV.fetch("DATABASE_PATH") do
      File.join(ROOT, "db/#{ENV.fetch('RACK_ENV', 'development')}.sqlite3")
    end
  end

  attr_reader :db, :catalog_queries, :package_service

  def initialize(db:)
    @db = db
    catalog_repository = Infrastructure::Persistence::SequelCatalogRepository.new(db)
    @catalog_queries = Application::CatalogQueries.new(catalog_repository: catalog_repository)
    @package_service = Application::PackageService.new(
      catalog_repository: catalog_repository,
      package_repository: Infrastructure::Persistence::SequelPackageRepository.new(db)
    )
  end

  # Brings a database up to date: runs pending migrations and seeds the
  # catalog when it is empty. Safe to call on every boot.
  def self.prepare(db, logger: $stdout)
    Infrastructure::Persistence::Database.migrate!(db)
    return unless db[:services].empty?

    logger.puts "[boot] catalog empty - seeding from #{SEED_FILE}"
    Infrastructure::Persistence::CatalogSeeder.new(db).seed_file(SEED_FILE)
  end
end
