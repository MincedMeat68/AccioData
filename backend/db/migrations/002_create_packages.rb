# frozen_string_literal: true

# User-built packages. Only the selection is stored; prices are recomputed
# from the catalog when read (see docs/adr/0003).
Sequel.migration do
  change do
    create_table(:packages) do
      String :id, primary_key: true # UUID
      String :name, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
      index :updated_at
    end

    create_table(:package_items) do
      foreign_key :package_id, :packages, type: String, null: false, on_delete: :cascade
      foreign_key :service_code, :services, type: String, null: false
      Integer :position, null: false
      primary_key %i[package_id service_code]
    end
  end
end
