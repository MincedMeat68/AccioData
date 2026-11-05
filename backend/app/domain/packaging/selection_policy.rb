# frozen_string_literal: true

module Domain
  module Packaging
    # Domain service that interprets the catalog's requirement and conflict
    # rules against a selection of service codes. Stateless and side-effect
    # free: it answers questions and leaves the changes to the Package
    # aggregate.
    class SelectionPolicy
      Availability = Data.define(:service_code, :status, :violations, :removal_cascade)
      # status: :selected | :available | :blocked (missing prerequisite) |
      #         :conflict (clashes with a selected service)

      def initialize(catalog)
        @catalog = catalog
      end

      # Every rule the selection currently breaks.
      def violations(codes)
        unknown = codes.reject { |c| @catalog.include?(c) }
        return unknown.map { |c| unknown_service(c) } if unknown.any?

        duplicates(codes) + missing_requirements(codes) + conflicts_within(codes)
      end

      def valid?(codes) = violations(codes).empty?

      # What would stop `code` from being added to `codes`?
      def violations_for_add(codes, code)
        return [unknown_service(code)] unless @catalog.include?(code)
        return [already_selected(code)] if codes.include?(code)

        missing_requirements_for(codes, code) + conflicts_with_selection(codes, code)
      end

      # Selected services that must also go if `code` is removed: everything
      # that depends on it, directly or transitively. Returned in selection
      # order and excluding `code` itself.
      def removal_cascade(codes, code)
        found = []
        queue = [code]
        until queue.empty?
          current = queue.shift
          @catalog.dependents_of(current).each do |dependent|
            next unless codes.include?(dependent) && !found.include?(dependent)

            found << dependent
            queue << dependent
          end
        end
        codes.select { |c| found.include?(c) }
      end

      # Selected services that conflict with `code` and that `code` fully
      # includes, so they can be swapped out for it automatically.
      def replaceable_by(codes, code)
        @catalog.conflicts_for(code)
                .select { |rule| rule.supersedes && rule.service_code == code }
                .map(&:conflicts_with_code)
                .select { |c| codes.include?(c) }
      end

      # Status of every catalog service against the current selection, so a
      # UI can show available / selected / blocked / conflict states.
      def availability(codes)
        @catalog.services.map do |service|
          code = service.code
          if codes.include?(code)
            Availability.new(service_code: code, status: :selected, violations: [],
                             removal_cascade: removal_cascade(codes, code))
          else
            problems = violations_for_add(codes, code)
            status = if problems.any? { |v| v.type == :missing_requirement } then :blocked
                     elsif problems.any? { |v| v.type == :conflict } then :conflict
                     else :available
                     end
            Availability.new(service_code: code, status: status, violations: problems, removal_cascade: [])
          end
        end
      end

      def name_of(code) = @catalog.include?(code) ? @catalog.name_of(code) : code

      private

      def duplicates(codes)
        codes.tally.select { |_, n| n > 1 }.keys.map do |code|
          Violation.new(type: :duplicate_service, service_code: code, related_codes: [],
                        message: "#{name_of(code)} is in the package more than once")
        end
      end

      def missing_requirements(codes)
        codes.uniq.flat_map { |code| missing_requirements_for(codes, code) }
      end

      def missing_requirements_for(codes, code)
        missing = @catalog.prerequisites_of(code).reject { |p| codes.include?(p) }
        missing.map do |prereq|
          Violation.new(type: :missing_requirement, service_code: code, related_codes: [prereq],
                        message: "#{name_of(code)} requires #{name_of(prereq)} to be added first")
        end
      end

      def conflicts_within(codes)
        @catalog.conflicts.select { |rule| codes.include?(rule.service_code) && codes.include?(rule.conflicts_with_code) }
                .map { |rule| conflict(rule.service_code, rule) }
      end

      def conflicts_with_selection(codes, code)
        @catalog.conflicts_for(code)
                .select { |rule| codes.include?(rule.other(code)) }
                .map { |rule| conflict(code, rule) }
      end

      def conflict(code, rule)
        other = rule.other(code)
        reason = rule.reason.to_s.empty? ? "" : " - #{rule.reason}"
        Violation.new(type: :conflict, service_code: code, related_codes: [other],
                      message: "#{name_of(code)} conflicts with #{name_of(other)}#{reason}")
      end

      def unknown_service(code)
        Violation.new(type: :unknown_service, service_code: code, related_codes: [],
                      message: "Unknown service: #{code}")
      end

      def already_selected(code)
        Violation.new(type: :already_selected, service_code: code, related_codes: [],
                      message: "#{name_of(code)} is already in the package")
      end
    end
  end
end
