# frozen_string_literal: true

module Domain
  class Error < StandardError; end

  # Raised when an operation would leave an aggregate in an invalid state.
  # Carries the full list of rule violations so callers can show all of them.
  class ValidationError < Error
    attr_reader :violations

    def initialize(violations)
      @violations = Array(violations)
      super(@violations.map(&:message).join("; "))
    end
  end

  class UnknownServiceError < Error
    attr_reader :code

    def initialize(code)
      @code = code
      super("Unknown service: #{code}")
    end
  end
end
