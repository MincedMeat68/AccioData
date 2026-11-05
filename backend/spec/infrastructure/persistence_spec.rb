# frozen_string_literal: true

RSpec.describe "SQLite persistence" do
  let(:db) { TestSupport.database }

  describe Infrastructure::Persistence::CatalogSeeder do
    it "seeds the catalog from YAML" do
      expect(db[:services].count).to eq(10)
      expect(db[:service_requirements].count).to eq(2)
      expect(db[:service_conflicts].count).to eq(1)
      expect(db[:discount_rules].order(:position).select_map(:code)).to eq(%w[volume criminal_bundle verification_bundle])
    end

    it "is idempotent and applies edits on re-run" do
      seeder = described_class.new(db)
      data = YAML.safe_load_file(Container::SEED_FILE)
      data["services"].find { |s| s["code"] == "mvr" }["price_cents"] = 2200

      seeder.seed(data)
      seeder.seed(data)

      expect(db[:services].count).to eq(10)
      expect(db[:services][code: "mvr"][:price_cents]).to eq(2200)
    end

    it "rolls back entirely when the seed is invalid" do
      bad = YAML.safe_load_file(Container::SEED_FILE)
      bad["rules"]["requirements"] << { "service" => "mvr", "requires" => "does_not_exist" }

      expect { described_class.new(db).seed(bad) }.to raise_error(Sequel::ForeignKeyConstraintViolation)
      expect(db[:service_requirements].count).to eq(2)
    end
  end

  describe Infrastructure::Persistence::SequelCatalogRepository do
    it "rebuilds rules and discount strategies from the tables" do
      catalog = described_class.new(db).load

      expect(catalog.prerequisites_of("county_criminal")).to eq(["state_criminal"])
      expect(catalog.conflicts.first.supersedes).to be(true)
      bundle = catalog.discount_rules.find { |d| d.code == "criminal_bundle" }
      expect(bundle.service_codes).to eq(%w[state_criminal county_criminal federal_criminal national_criminal])
    end
  end

  describe Infrastructure::Persistence::SequelPackageRepository do
    subject(:repo) { described_class.new(db) }

    def package(id, codes, at)
      Domain::Packaging::Package.rehydrate(id: id, name: "Pkg #{id}", service_codes: codes, created_at: at, updated_at: at)
    end

    it "round-trips a package, preserving service order" do
      repo.save(package("a", %w[mvr state_criminal county_criminal], Time.utc(2026, 1, 1)))
      found = repo.find("a")

      expect(found.service_codes).to eq(%w[mvr state_criminal county_criminal])
      expect(found.updated_at).to eq(Time.utc(2026, 1, 1))
    end

    it "updates in place and orders by most recently updated" do
      repo.save(package("a", ["mvr"], Time.utc(2026, 1, 1)))
      repo.save(package("b", ["mvr"], Time.utc(2026, 1, 2)))
      expect(repo.latest.id).to eq("b")

      updated = repo.find("a")
      updated.revise(name: "Pkg a v2", service_codes: ["state_criminal"],
                     policy: Domain::Packaging::SelectionPolicy.new(TestSupport.catalog), now: Time.utc(2026, 1, 3))
      repo.save(updated)

      expect(repo.all.map(&:id)).to eq(%w[a b])
      expect(repo.find("a").service_codes).to eq(["state_criminal"])
      expect(db[:packages].count).to eq(2)
    end

    it "deletes a package and its items" do
      repo.save(package("a", %w[mvr state_criminal], Time.utc(2026, 1, 1)))

      expect(repo.delete("a")).to be(true)
      expect(repo.delete("a")).to be(false)
      expect(db[:package_items].count).to eq(0)
    end

    it "refuses items that reference unknown services" do
      expect { repo.save(package("a", ["bogus"], Time.utc(2026, 1, 1))) }
        .to raise_error(Sequel::ForeignKeyConstraintViolation)
    end
  end
end
