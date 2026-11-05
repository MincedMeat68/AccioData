# frozen_string_literal: true

require "securerandom"

module Application
  # Use cases for saved packages. Each public method is one use case: it
  # loads what it needs, asks the domain to make the change (which enforces
  # the invariants), persists, and returns a PricedPackage.
  class PackageService
    def initialize(catalog_repository:, package_repository:, clock: -> { Time.now.utc },
                   id_generator: -> { SecureRandom.uuid })
      @catalog_repository = catalog_repository
      @packages = package_repository
      @clock = clock
      @id_generator = id_generator
    end

    def create(name:, service_codes:)
      package = Domain::Packaging::Package.create(
        id: @id_generator.call, name: name, service_codes: Array(service_codes),
        policy: policy, now: @clock.call
      )
      priced(@packages.save(package))
    end

    def update(id:, name:, service_codes:)
      package = find!(id)
      package.revise(name: name, service_codes: Array(service_codes), policy: policy, now: @clock.call)
      priced(@packages.save(package))
    end

    def duplicate(id:, name: nil)
      copy = find!(id).duplicate(new_id: @id_generator.call, name: name, now: @clock.call)
      copy.validate!(policy)
      priced(@packages.save(copy))
    end

    def delete(id:)
      raise NotFound.new("Package", id) unless @packages.delete(id)

      true
    end

    def get(id:) = priced(find!(id))

    # The most recently saved (created or updated) package, or nil.
    def latest
      package = @packages.latest
      package && priced(package)
    end

    def list
      cat = catalog
      @packages.all.map { |p| priced(p, cat) }
    end

    private

    def find!(id) = @packages.find(id) || raise(NotFound.new("Package", id))

    def catalog = @catalog_repository.load

    def policy = Domain::Packaging::SelectionPolicy.new(catalog)

    # Packages are not re-validated on load (rules may change after saving),
    # so report any violations alongside the quote instead of failing.
    def priced(package, cat = catalog)
      known = package.service_codes.select { |c| cat.include?(c) }
      PricedPackage.new(
        package: package,
        quote: Domain::Pricing::PricingEngine.new(cat).quote(known),
        violations: Domain::Packaging::SelectionPolicy.new(cat).violations(package.service_codes)
      )
    end
  end
end
