# frozen_string_literal: true

module Infrastructure
  module Persistence
    # PackageRepository adapter that keeps packages in a Hash. Used by the
    # application-layer specs so use cases can be tested without a database.
    class InMemoryPackageRepository
      include Domain::Packaging::PackageRepository

      def initialize
        @store = {}
      end

      def find(id) = copy(@store[id])
      def latest = copy(sorted.first)
      def all = sorted.map { |p| copy(p) }
      def delete(id) = !@store.delete(id).nil?

      def save(package)
        @store[package.id] = copy(package)
        package
      end

      private

      def sorted = @store.values.sort_by { |p| [p.updated_at, p.created_at] }.reverse

      # Hand out copies so callers cannot mutate stored state without save.
      def copy(package)
        return nil unless package

        Domain::Packaging::Package.rehydrate(
          id: package.id, name: package.name, service_codes: package.service_codes,
          created_at: package.created_at, updated_at: package.updated_at
        )
      end
    end
  end
end
