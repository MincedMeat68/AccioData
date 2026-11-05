# frozen_string_literal: true

module Application
  # Read-side use cases over the catalog and over unsaved selections.
  class CatalogQueries
    def initialize(catalog_repository:)
      @catalog_repository = catalog_repository
    end

    def catalog = @catalog_repository.load

    # Prices and validates a selection without saving it. Unknown or
    # duplicate codes are reported as violations; the quote covers the known,
    # distinct services so the user still sees a price.
    def evaluate(service_codes)
      catalog = self.catalog
      codes = Array(service_codes).map(&:to_s)
      policy = Domain::Packaging::SelectionPolicy.new(catalog)
      priceable = codes.uniq.select { |c| catalog.include?(c) }

      Evaluation.new(
        quote: Domain::Pricing::PricingEngine.new(catalog).quote(priceable),
        violations: policy.violations(codes),
        availability: policy.availability(priceable)
      )
    end

    def templates
      catalog = self.catalog
      engine = Domain::Pricing::PricingEngine.new(catalog)
      catalog.templates.map { |t| PricedTemplate.new(template: t, quote: engine.quote(t.service_codes)) }
    end
  end
end
