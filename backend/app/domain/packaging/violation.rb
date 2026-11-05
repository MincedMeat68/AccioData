# frozen_string_literal: true

module Domain
  module Packaging
    # A broken business rule, phrased for the end user.
    #
    # type:          :missing_requirement | :conflict | :unknown_service |
    #                :duplicate_service | :already_selected | :not_selected |
    #                :has_dependents | :invalid_name | :empty_package
    # service_code:  the service the violation is about (nil for package-level)
    # related_codes: the other services involved (prerequisites, conflicting
    #                services, dependents)
    Violation = Data.define(:type, :service_code, :related_codes, :message) do
      def self.package_level(type, message) = new(type: type, service_code: nil, related_codes: [], message: message)
    end
  end
end
