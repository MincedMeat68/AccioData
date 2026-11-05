# frozen_string_literal: true

module Domain
  module Pricing
    # Discount rules are strategy objects with one method:
    #
    #   apply(services, subtotal) -> DiscountLine or nil
    #
    # where `services` are the Catalog::Service objects in the package. Adding
    # a new kind of discount means adding a class here and a mapping in
    # Infrastructure::Persistence::DiscountRuleMapper; the engine never changes.
    module Discounts
      # Percentage off the subtotal based on how many services are in the
      # package. Only the highest tier reached applies (tiers do not stack
      # with each other).
      class VolumeDiscount
        Tier = Data.define(:min_services, :percent)

        attr_reader :code, :tiers

        def initialize(code:, tiers:)
          @code = code
          @tiers = tiers.sort_by { |t| -t.min_services }.freeze
        end

        def apply(services, subtotal)
          tier = tiers.find { |t| services.size >= t.min_services }
          return nil unless tier

          DiscountLine.new(
            code: code,
            label: "Volume Discount (#{format_percent(tier.percent)}% for #{tier.min_services}+ services)",
            amount: subtotal.percent(tier.percent)
          )
        end

        private

        def format_percent(percent) = percent == percent.to_i ? percent.to_i : percent
      end

      # Flat amount off when every service in a set (e.g. a whole category)
      # is in the package.
      class BundleDiscount
        attr_reader :code, :name, :service_codes, :amount

        def initialize(code:, name:, service_codes:, amount:)
          raise ArgumentError, "bundle #{code} has no services" if service_codes.empty?

          @code = code
          @name = name
          @service_codes = service_codes.freeze
          @amount = amount
        end

        def apply(services, _subtotal)
          selected = services.map(&:code)
          return nil unless (service_codes - selected).empty?

          DiscountLine.new(code: code, label: name, amount: amount)
        end
      end
    end
  end
end
