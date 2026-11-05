# frozen_string_literal: true

module Domain
  module Catalog
    # Read-only reference data: the services on offer plus the rules that
    # govern how they combine and how they are priced. Built by a
    # CatalogRepository; the domain never knows where it was loaded from.
    class ServiceCatalog
      attr_reader :categories, :services, :requirements, :conflicts, :discount_rules, :templates

      def initialize(categories:, services:, requirements: [], conflicts: [], discount_rules: [], templates: [])
        @categories = categories.freeze
        @services = services.freeze
        @requirements = requirements.freeze
        @conflicts = conflicts.freeze
        @discount_rules = discount_rules.freeze
        @templates = templates.freeze
        @by_code = services.to_h { |s| [s.code, s] }.freeze
        freeze
      end

      def fetch(code)
        @by_code.fetch(code) { raise UnknownServiceError, code }
      end

      def include?(code) = @by_code.key?(code)

      def name_of(code) = fetch(code).name

      def services_in(category_code) = services.select { |s| s.category_code == category_code }

      # Codes that `code` directly requires.
      def prerequisites_of(code)
        requirements.select { |r| r.service_code == code }.map(&:requires_code)
      end

      # Codes that directly require `code`.
      def dependents_of(code)
        requirements.select { |r| r.requires_code == code }.map(&:service_code)
      end

      def conflicts_for(code) = conflicts.select { |c| c.involves?(code) }

      def template(code) = templates.find { |t| t.code == code }
    end
  end
end
