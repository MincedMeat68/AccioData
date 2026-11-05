# frozen_string_literal: true

require "json"
require "yaml"

module Infrastructure
  module Persistence
    # Loads db/seeds/catalog.yml into the catalog tables. Idempotent: running
    # it again applies YAML edits. Categories and services are upserted, never
    # deleted, because saved packages reference them. Rules, discounts and
    # templates are replaced as a whole. Everything runs in one transaction,
    # so a bad seed file leaves the database unchanged.
    class CatalogSeeder
      def initialize(db)
        @db = db
      end

      def seed_file(path) = seed(YAML.safe_load_file(path))

      def seed(data)
        @db.transaction do
          upsert_categories(data.fetch("categories"))
          upsert_services(data.fetch("services"))
          replace_rules(data.fetch("rules", {}))
          replace_discounts(data.fetch("discounts", []))
          replace_templates(data.fetch("templates", []))
        end
      end

      private

      def upsert_categories(categories)
        categories.each_with_index do |c, i|
          upsert(:categories, :code, code: c.fetch("code"), name: c.fetch("name"), position: i)
        end
      end

      def upsert_services(services)
        services.each_with_index do |s, i|
          upsert(:services, :code,
                 code: s.fetch("code"), name: s.fetch("name"), category_code: s.fetch("category"),
                 price_cents: Integer(s.fetch("price_cents")), description: s["description"], position: i)
        end
      end

      def replace_rules(rules)
        @db[:service_requirements].delete
        @db[:service_conflicts].delete
        rules.fetch("requirements", []).each do |r|
          @db[:service_requirements].insert(service_code: r.fetch("service"), requires_code: r.fetch("requires"))
        end
        rules.fetch("conflicts", []).each do |c|
          @db[:service_conflicts].insert(service_code: c.fetch("service"), conflicts_with_code: c.fetch("conflicts_with"),
                                         supersedes: c.fetch("supersedes", false), reason: c["reason"])
        end
      end

      def replace_discounts(discounts)
        @db[:discount_rules].delete
        discounts.each_with_index do |d, i|
          params = d.reject { |k, _| %w[type code name].include?(k) }
          @db[:discount_rules].insert(code: d.fetch("code"), type: d.fetch("type"), name: d["name"],
                                      params: JSON.generate(params), position: i)
        end
      end

      def replace_templates(templates)
        @db[:package_template_items].delete
        @db[:package_templates].delete
        templates.each_with_index do |t, i|
          @db[:package_templates].insert(code: t.fetch("code"), name: t.fetch("name"), position: i)
          t.fetch("services").each_with_index do |code, j|
            @db[:package_template_items].insert(template_code: t.fetch("code"), service_code: code, position: j)
          end
        end
      end

      def upsert(table, key, row)
        @db[table].insert_conflict(target: key, update: row.except(key)).insert(row)
      end
    end
  end
end
