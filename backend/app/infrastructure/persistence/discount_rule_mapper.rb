# frozen_string_literal: true

require "json"

module Infrastructure
  module Persistence
    # Turns a discount_rules row (type + JSON params) into a domain strategy
    # object. To add a new kind of discount: write the class in
    # Domain::Pricing::Discounts, add a branch here, add a row to the seed.
    module DiscountRuleMapper
      Discounts = Domain::Pricing::Discounts

      def self.build(row, services)
        params = JSON.parse(row.fetch(:params))
        case row.fetch(:type)
        when "volume"
          tiers = params.fetch("tiers").map do |t|
            Discounts::VolumeDiscount::Tier.new(min_services: Integer(t.fetch("min_services")), percent: t.fetch("percent"))
          end
          Discounts::VolumeDiscount.new(code: row.fetch(:code), tiers: tiers)
        when "bundle"
          Discounts::BundleDiscount.new(
            code: row.fetch(:code),
            name: row.fetch(:name),
            service_codes: bundle_services(params, services),
            amount: Domain::Money.from_cents(params.fetch("amount_cents"))
          )
        else
          raise ArgumentError, "Unknown discount type #{row[:type].inspect} for rule #{row[:code]}"
        end
      end

      # A bundle is either a whole category or an explicit list of services.
      def self.bundle_services(params, services)
        return params.fetch("service_codes") if params.key?("service_codes")

        category = params.fetch("category")
        services.select { |s| s.category_code == category }.map(&:code)
      end
    end
  end
end
