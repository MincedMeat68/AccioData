# frozen_string_literal: true

module Domain
  module Catalog
    # `service_code` may only be in a package when `requires_code` is too.
    RequirementRule = Data.define(:service_code, :requires_code)

    # The two services may not be in the same package. When `supersedes` is
    # true, `service_code` fully includes `conflicts_with_code`, so replacing
    # the lesser service is a safe resolution to offer the user.
    ConflictRule = Data.define(:service_code, :conflicts_with_code, :supersedes, :reason) do
      def involves?(code) = [service_code, conflicts_with_code].include?(code)

      def other(code)
        return conflicts_with_code if code == service_code
        return service_code if code == conflicts_with_code

        nil
      end
    end

    # A predefined package. Its price is computed, never stored.
    Template = Data.define(:code, :name, :service_codes)
  end
end
