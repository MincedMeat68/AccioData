# frozen_string_literal: true

module Application
  class NotFound < StandardError
    def initialize(what, id) = super("#{what} #{id} not found")
  end

  # A package together with its freshly computed quote. Prices are always
  # computed from the current catalog (price snapshots are future work, see
  # docs/adr/0003).
  PricedPackage = Data.define(:package, :quote, :violations)

  # Answer to "what does this selection look like?": price, broken rules and
  # per-service availability. Drives the builder's real-time feedback.
  Evaluation = Data.define(:quote, :violations, :availability)

  PricedTemplate = Data.define(:template, :quote)
end
