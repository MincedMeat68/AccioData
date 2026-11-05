# frozen_string_literal: true

module Infrastructure
  module Persistence
    # PackageRepository adapter for SQLite via Sequel. Maps between the
    # Package aggregate and the packages / package_items tables; the
    # aggregate is always saved and loaded as a whole.
    class SequelPackageRepository
      include Domain::Packaging::PackageRepository

      def initialize(db)
        @db = db
      end

      def find(id)
        row = @db[:packages][id: id]
        row && to_entity(row, items_for([id]).fetch(id, []))
      end

      def latest
        row = ordered.first
        row && to_entity(row, items_for([row[:id]]).fetch(row[:id], []))
      end

      def all
        rows = ordered.to_a
        items = items_for(rows.map { |r| r[:id] })
        rows.map { |r| to_entity(r, items.fetch(r[:id], [])) }
      end

      def save(package)
        @db.transaction do
          row = { id: package.id, name: package.name, created_at: package.created_at, updated_at: package.updated_at }
          @db[:packages].insert_conflict(target: :id, update: row.except(:id, :created_at)).insert(row)
          @db[:package_items].where(package_id: package.id).delete
          @db[:package_items].multi_insert(
            package.service_codes.each_with_index.map { |code, i| { package_id: package.id, service_code: code, position: i } }
          )
        end
        package
      end

      # package_items rows go with it via ON DELETE CASCADE.
      def delete(id) = @db[:packages].where(id: id).delete.positive?

      private

      def ordered = @db[:packages].order(Sequel.desc(:updated_at), Sequel.desc(:created_at))

      def items_for(ids)
        @db[:package_items].where(package_id: ids).order(:position)
                           .to_a.group_by { |r| r[:package_id] }
                           .transform_values { |rs| rs.map { |r| r[:service_code] } }
      end

      def to_entity(row, codes)
        Domain::Packaging::Package.rehydrate(
          id: row[:id], name: row[:name], service_codes: codes,
          created_at: row[:created_at], updated_at: row[:updated_at]
        )
      end
    end
  end
end
