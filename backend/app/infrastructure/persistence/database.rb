# frozen_string_literal: true

require "sequel"

module Infrastructure
  module Persistence
    module Database
      MIGRATIONS_DIR = File.expand_path("../../../db/migrations", __dir__)

      Sequel.default_timezone = :utc

      # Connects to a SQLite file by path (works on Windows drive-letter
      # paths, which sqlite:// URLs do not). nil or ":memory:" gives an
      # in-memory database for tests. Sequel's SQLite adapter turns on
      # `PRAGMA foreign_keys` by default.
      def self.connect(path)
        path.nil? || path == ":memory:" ? Sequel.sqlite : Sequel.sqlite(path)
      end

      def self.migrate!(db)
        Sequel.extension :migration
        Sequel::Migrator.run(db, MIGRATIONS_DIR)
      end
    end
  end
end
