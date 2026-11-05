# frozen_string_literal: true

module Infrastructure
  module Persistence
    # CatalogRepository adapter backed by the SQLite catalog tables. The
    # catalog is a handful of rows, so it is read fresh on every call; edits
    # in the database take effect without restarting the server.
    class SequelCatalogRepository
      include Domain::Catalog::CatalogRepository
      Catalog = Domain::Catalog

      def initialize(db)
        @db = db
      end

      def load
        services = @db[:services].order(:position).map do |r|
          Catalog::Service.new(code: r[:code], name: r[:name], category_code: r[:category_code],
                               price: Domain::Money.from_cents(r[:price_cents]), description: r[:description])
        end

        Catalog::ServiceCatalog.new(
          categories: @db[:categories].order(:position).map { |r| Catalog::Category.new(code: r[:code], name: r[:name]) },
          services: services,
          requirements: @db[:service_requirements].map do |r|
            Catalog::RequirementRule.new(service_code: r[:service_code], requires_code: r[:requires_code])
          end,
          conflicts: @db[:service_conflicts].map do |r|
            Catalog::ConflictRule.new(service_code: r[:service_code], conflicts_with_code: r[:conflicts_with_code],
                                      supersedes: !!r[:supersedes], reason: r[:reason])
          end,
          discount_rules: @db[:discount_rules].order(:position).map { |r| DiscountRuleMapper.build(r, services) },
          templates: load_templates
        )
      end

      private

      def load_templates
        items = @db[:package_template_items].order(:position).to_a.group_by { |r| r[:template_code] }
        @db[:package_templates].order(:position).map do |t|
          Catalog::Template.new(code: t[:code], name: t[:name],
                                service_codes: items.fetch(t[:code], []).map { |i| i[:service_code] })
        end
      end
    end
  end
end
