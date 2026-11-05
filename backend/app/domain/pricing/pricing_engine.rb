# frozen_string_literal: true

module Domain
  module Pricing
    # Prices a selection of services. Every discount rule is evaluated
    # against the undiscounted subtotal and all applicable discounts stack
    # (spec: "Discounts stack"). The total never goes below zero.
    class PricingEngine
      def initialize(catalog)
        @catalog = catalog
      end

      def quote(service_codes)
        services = service_codes.map { |code| @catalog.fetch(code) }
        subtotal = services.sum(Money.zero, &:price)
        discounts = @catalog.discount_rules.filter_map { |rule| rule.apply(services, subtotal) }
        total = discounts.reduce(subtotal) { |sum, d| sum - d.amount }.clamp_at_zero

        PriceQuote.new(
          line_items: services.map { |s| LineItem.new(service_code: s.code, name: s.name, price: s.price) },
          subtotal: subtotal,
          discounts: discounts,
          total: total
        )
      end
    end
  end
end
