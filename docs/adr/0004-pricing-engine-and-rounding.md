# ADR 0004: Pricing engine built from discount strategies; integer cents with half-up rounding

**Status:** Accepted

## Context

Spec decision point 3: *How will you handle the pricing calculation? Consider maintainability if new discount rules are added.*

## Decision

- **Money** is an immutable value object holding **integer cents**, so totals never pick up floating-point error. Percentages are calculated with `Rational` and **rounded half-up to the nearest cent**. Every example in the spec divides exactly, so this rounding rule is our own choice, and it is documented here.
- **`PricingEngine#quote(codes)`** works in four steps:
  1. Sum the subtotal.
  2. Ask each `DiscountRule` (in the order set in the database) to `apply(services, subtotal)`. Each rule returns a `DiscountLine` or nil.
  3. Subtract all the returned discounts.
  4. Clamp the total at $0.
- **Every discount is calculated from the undiscounted subtotal.** This matches the appendix: Example 3 takes 15% of $230 and *then* subtracts the $20 and $15 bundles. Calculating the volume discount after the bundles would give a different total.
- **Volume tiers don't stack with each other.** Only the highest tier reached applies (5+ = 10%, 8+ = 15%), and its label states the tier: "Volume Discount (15% for 8+ services)".
- **A bundle** applies when *every* service in its set is selected. The set is either a whole category or an explicit list of services.
- The result is a `PriceQuote` with the line items, subtotal, itemized `DiscountLine`s and total, so the UI can show exactly how the price was reached.

## Adding a new discount

1. Write a class with `apply(services, subtotal) -> DiscountLine | nil` in `Domain::Pricing::Discounts`.
2. Add a branch to `DiscountRuleMapper`, and to `Serializers.discount_rule` if the UI should know about it.
3. Add a row to `discounts:` in the seed YAML.

The engine, the use cases and the routes stay the same.
