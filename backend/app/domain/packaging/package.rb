# frozen_string_literal: true

module Domain
  module Packaging
    # Aggregate root. A named, ordered selection of catalog services.
    #
    # Invariants (enforced by every state-changing method):
    #   * the name is present and at most NAME_MAX characters
    #   * at least one service is selected
    #   * every selected service's prerequisites are also selected
    #   * no two selected services conflict
    #
    # Mutations raise Domain::ValidationError and leave the package unchanged
    # when they would break an invariant. Mutations that need confirmation
    # (cascading removal, conflict replacement) must be requested explicitly.
    class Package
      NAME_MAX = 100

      attr_reader :id, :name, :service_codes, :created_at, :updated_at

      def self.create(id:, name:, service_codes:, policy:, now:)
        new(id: id, name: name, service_codes: service_codes, created_at: now, updated_at: now)
          .tap { |pkg| pkg.validate!(policy) }
      end

      # Rebuilds a package already persisted. Not re-validated: catalog rules
      # may have changed since it was saved, and loading must still work so
      # the user can fix it (see docs/adr/0003).
      def self.rehydrate(**attrs) = new(**attrs)

      def initialize(id:, name:, service_codes:, created_at:, updated_at:)
        @id = id
        @name = name.to_s.strip
        @service_codes = service_codes.dup.freeze
        @created_at = created_at
        @updated_at = updated_at
      end

      def include?(code) = service_codes.include?(code)

      # Adds a service. With replace_conflicts: true, selected services that
      # the new one supersedes are swapped out (e.g. 5-Panel -> 10-Panel).
      def add(code, policy, replace_conflicts: false, now: Time.now)
        current = service_codes
        current -= policy.replaceable_by(current, code) if replace_conflicts
        problems = policy.violations_for_add(current, code)
        raise ValidationError, problems if problems.any?

        change(service_codes: current + [code], now: now)
      end

      # Removes a service. If other selected services depend on it, removal is
      # refused unless cascade: true, in which case they are removed too.
      def remove(code, policy, cascade: false, now: Time.now)
        unless include?(code)
          raise ValidationError, [Violation.new(type: :not_selected, service_code: code, related_codes: [],
                                                message: "#{policy.name_of(code)} is not in the package")]
        end

        dependents = policy.removal_cascade(service_codes, code)
        if dependents.any? && !cascade
          raise ValidationError, [has_dependents(code, dependents, policy)]
        end

        change(service_codes: service_codes - [code] - dependents, now: now)
      end

      # Replaces name and selection in one step (the builder UI edits a draft
      # client-side and saves the whole thing).
      def revise(name:, service_codes:, policy:, now: Time.now)
        candidate = self.class.new(id: id, name: name, service_codes: service_codes,
                                   created_at: created_at, updated_at: now)
        candidate.validate!(policy)
        @name = candidate.name
        @service_codes = candidate.service_codes
        @updated_at = now
        self
      end

      def duplicate(new_id:, name: nil, now: Time.now)
        self.class.new(id: new_id, name: name || copy_name, service_codes: service_codes,
                       created_at: now, updated_at: now)
      end

      def violations(policy)
        name_violations + selection_violations + policy.violations(service_codes)
      end

      def validate!(policy)
        problems = violations(policy)
        raise ValidationError, problems if problems.any?

        self
      end

      private

      def change(service_codes:, now:)
        @service_codes = service_codes.freeze
        @updated_at = now
        self
      end

      def name_violations
        if name.empty?
          [Violation.package_level(:invalid_name, "Package name is required")]
        elsif name.length > NAME_MAX
          [Violation.package_level(:invalid_name, "Package name must be #{NAME_MAX} characters or fewer")]
        else
          []
        end
      end

      def selection_violations
        return [] if service_codes.any?

        [Violation.package_level(:empty_package, "Add at least one service to the package")]
      end

      def has_dependents(code, dependents, policy)
        Violation.new(
          type: :has_dependents, service_code: code, related_codes: dependents,
          message: "Removing #{policy.name_of(code)} will also remove " \
                   "#{dependents.map { |d| policy.name_of(d) }.join(' and ')}"
        )
      end

      def copy_name
        candidate = "Copy of #{name}"
        candidate.length > NAME_MAX ? candidate[0, NAME_MAX] : candidate
      end
    end
  end
end
