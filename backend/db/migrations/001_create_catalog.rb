# frozen_string_literal: true

# Reference data: services and the rules that govern them. Populated by
# `rake db:seed` from db/seeds/catalog.yml.
Sequel.migration do
  change do
    create_table(:categories) do
      String :code, primary_key: true
      String :name, null: false
      Integer :position, null: false
    end

    create_table(:services) do
      String :code, primary_key: true
      String :name, null: false
      foreign_key :category_code, :categories, type: String, null: false
      Integer :price_cents, null: false
      String :description, text: true
      Integer :position, null: false
      constraint(:price_non_negative) { price_cents >= 0 }
    end

    create_table(:service_requirements) do
      foreign_key :service_code, :services, type: String, null: false
      foreign_key :requires_code, :services, type: String, null: false
      primary_key %i[service_code requires_code]
    end

    create_table(:service_conflicts) do
      foreign_key :service_code, :services, type: String, null: false
      foreign_key :conflicts_with_code, :services, type: String, null: false
      TrueClass :supersedes, null: false, default: false
      String :reason
      primary_key %i[service_code conflicts_with_code]
    end

    # Discount rules differ in shape (tiers vs flat amount), so the
    # type-specific settings live in a JSON `params` column and
    # DiscountRuleMapper turns each row into the matching strategy object.
    create_table(:discount_rules) do
      String :code, primary_key: true
      String :type, null: false
      String :name
      String :params, text: true, null: false
      Integer :position, null: false
    end

    create_table(:package_templates) do
      String :code, primary_key: true
      String :name, null: false
      Integer :position, null: false
    end

    create_table(:package_template_items) do
      foreign_key :template_code, :package_templates, type: String, null: false, on_delete: :cascade
      foreign_key :service_code, :services, type: String, null: false
      Integer :position, null: false
      primary_key %i[template_code service_code]
    end
  end
end
