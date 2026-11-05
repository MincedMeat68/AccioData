# frozen_string_literal: true

module Domain
  # Immutable money value object. Amounts are integer cents (USD) so that
  # arithmetic is exact; percentages round half-up to the nearest cent.
  Money = Data.define(:cents) do
    def self.zero = new(cents: 0)
    def self.from_cents(cents) = new(cents: Integer(cents))

    def +(other) = Money.new(cents: cents + other.cents)
    def -(other) = Money.new(cents: cents - other.cents)
    def negative? = cents.negative?
    def zero? = cents.zero?
    def <=>(other) = cents <=> other.cents
    include Comparable

    # Returns `percent`% of this amount, rounded half-up to the cent.
    def percent(percent)
      Money.new(cents: (Rational(cents) * Rational(percent) / 100).round(half: :up))
    end

    def clamp_at_zero = negative? ? Money.zero : self

    def to_s
      sign = negative? ? "-" : ""
      dollars, rem = cents.abs.divmod(100)
      format("%s$%d.%02d", sign, dollars, rem)
    end
  end
end
