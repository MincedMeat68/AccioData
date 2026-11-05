# frozen_string_literal: true

module Domain
  module Pricing
    # One itemized discount on a quote. `amount` is a positive Money that is
    # subtracted from the subtotal.
    DiscountLine = Data.define(:code, :label, :amount)

    LineItem = Data.define(:service_code, :name, :price)

    PriceQuote = Data.define(:line_items, :subtotal, :discounts, :total) do
      def discount_total = discounts.sum(Money.zero) { |d| d.amount }
      def service_count = line_items.size
    end
  end
end
