# frozen_string_literal: true

module Domain
  module Packaging
    # Port for persisting Package aggregates. Implemented in
    # Infrastructure::Persistence (Sequel/SQLite for the app, in-memory for
    # tests). Documents the contract; Ruby duck typing does the rest.
    module PackageRepository
      def find(id) = raise(NotImplementedError)            # -> Package or nil
      def latest = raise(NotImplementedError)              # -> most recently updated Package or nil
      def all = raise(NotImplementedError)                 # -> [Package], most recently updated first
      def save(package) = raise(NotImplementedError)       # insert or update; -> package
      def delete(id) = raise(NotImplementedError)          # -> true if deleted, false if missing
    end
  end
end
