# frozen_string_literal: true

# Use cases tested against the in-memory repository: no database, real rules.
RSpec.describe Application::PackageService do
  subject(:service) do
    ids = (1..).lazy.map { |n| "pkg-#{n}" }
    described_class.new(
      catalog_repository: TestSupport::StaticCatalogRepository.new(TestSupport.catalog),
      package_repository: Infrastructure::Persistence::InMemoryPackageRepository.new,
      clock: TestSupport.ticking_clock,
      id_generator: -> { ids.next }
    )
  end

  let(:basic) { %w[state_criminal employment_verification drug_5_panel] }
  let(:standard) do
    %w[state_criminal county_criminal federal_criminal national_criminal
       employment_verification education_verification drug_5_panel]
  end

  it "Flow 1: saves a basic package priced at $95 with no discounts" do
    saved = service.create(name: "Standard Hire Package", service_codes: basic)

    expect(saved.package.id).to eq("pkg-1")
    expect(saved.quote.total.cents).to eq(9500)
    expect(saved.quote.discounts).to be_empty
    expect(service.get(id: "pkg-1").package.service_codes).to eq(basic)
  end

  it "Flow 5: editing a 7-service package to 8 moves it to the 15% tier" do
    created = service.create(name: "Standard Hire Package", service_codes: standard)
    expect(created.quote.discounts.map(&:code)).to eq(%w[volume criminal_bundle])
    expect(created.quote.discounts.first.label).to include("10%")

    updated = service.update(id: created.package.id, name: "Standard Hire Package", service_codes: standard + ["mvr"])

    expect(updated.quote.service_count).to eq(8)
    expect(updated.quote.discounts.first.label).to include("15%")
    expect(service.list.map { |p| p.package.service_codes.size }).to eq([8])
  end

  it "rejects invalid packages without saving them" do
    expect { service.create(name: "Bad", service_codes: ["county_criminal"]) }
      .to raise_error(Domain::ValidationError, /requires State Criminal Search/)
    expect(service.list).to be_empty
  end

  it "returns the most recently saved package, including updates" do
    expect(service.latest).to be_nil

    first = service.create(name: "First", service_codes: basic)
    service.create(name: "Second", service_codes: ["mvr"])
    expect(service.latest.package.name).to eq("Second")

    service.update(id: first.package.id, name: "First (edited)", service_codes: basic)
    expect(service.latest.package.name).to eq("First (edited)")
  end

  it "duplicates and deletes" do
    original = service.create(name: "Original", service_codes: basic)
    copy = service.duplicate(id: original.package.id)

    expect(copy.package.name).to eq("Copy of Original")
    expect(copy.package.service_codes).to eq(basic)

    service.delete(id: original.package.id)
    expect(service.list.map { |p| p.package.id }).to eq([copy.package.id])
  end

  it "raises NotFound for unknown ids" do
    expect { service.get(id: "missing") }.to raise_error(Application::NotFound)
    expect { service.update(id: "missing", name: "x", service_codes: ["mvr"]) }.to raise_error(Application::NotFound)
    expect { service.delete(id: "missing") }.to raise_error(Application::NotFound)
  end
end

RSpec.describe Application::CatalogQueries do
  subject(:queries) do
    described_class.new(catalog_repository: TestSupport::StaticCatalogRepository.new(TestSupport.catalog))
  end

  it "evaluates an unsaved selection: quote, violations and availability" do
    result = queries.evaluate(%w[county_criminal mvr])

    expect(result.violations.map(&:type)).to eq([:missing_requirement])
    expect(result.quote.subtotal.cents).to eq(4500)
    statuses = result.availability.to_h { |a| [a.service_code, a.status] }
    expect(statuses.values_at("county_criminal", "state_criminal", "federal_criminal"))
      .to eq(%i[selected available blocked])
  end

  it "still prices the known services when the selection has unknown codes" do
    result = queries.evaluate(%w[mvr bogus mvr])

    expect(result.violations.map(&:type)).to eq([:unknown_service])
    expect(result.quote.line_items.map(&:service_code)).to eq(["mvr"])
  end

  it "prices templates with the engine rather than stored prices" do
    totals = queries.templates.to_h { |t| [t.template.code, t.quote.total.cents] }
    expect(totals).to eq("basic" => 9500, "standard" => 18_250, "comprehensive" => 21_575)
  end
end
