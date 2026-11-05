# frozen_string_literal: true

RSpec.describe Domain::Packaging::Package do
  let(:policy) { Domain::Packaging::SelectionPolicy.new(TestSupport.catalog) }
  let(:now) { Time.utc(2026, 1, 1) }

  def build(codes, name: "Standard Hire Package")
    described_class.create(id: "pkg-1", name: name, service_codes: codes, policy: policy, now: now)
  end

  def violation_types
    yield
    raise "expected a ValidationError"
  rescue Domain::ValidationError => e
    e.violations.map(&:type)
  end

  describe ".create" do
    it "builds a valid package" do
      pkg = build(%w[state_criminal employment_verification drug_5_panel])
      expect(pkg.service_codes).to eq(%w[state_criminal employment_verification drug_5_panel])
      expect(pkg.name).to eq("Standard Hire Package")
    end

    it "enforces name, non-empty, dependency and conflict invariants" do
      expect(violation_types { build(["mvr"], name: "  ") }).to eq([:invalid_name])
      expect(violation_types { build(["mvr"], name: "x" * 101) }).to eq([:invalid_name])
      expect(violation_types { build([]) }).to eq([:empty_package])
      expect(violation_types { build(["county_criminal"]) }).to eq([:missing_requirement])
      expect(violation_types { build(%w[drug_5_panel drug_10_panel]) }).to eq([:conflict])
    end

    it "reports every broken rule at once" do
      expect(violation_types { build(%w[county_criminal drug_5_panel drug_10_panel], name: "") })
        .to contain_exactly(:invalid_name, :missing_requirement, :conflict)
    end
  end

  describe "#add" do
    let(:pkg) { build(["state_criminal"]) }

    it "adds a service whose prerequisite is present" do
      expect(pkg.add("county_criminal", policy).service_codes).to eq(%w[state_criminal county_criminal])
    end

    it "refuses a conflicting service and leaves the package unchanged" do
      pkg.add("drug_5_panel", policy)
      expect(violation_types { pkg.add("drug_10_panel", policy) }).to eq([:conflict])
      expect(pkg.service_codes).to eq(%w[state_criminal drug_5_panel])
    end

    it "replaces a superseded service when asked to" do
      pkg.add("drug_5_panel", policy)
      pkg.add("drug_10_panel", policy, replace_conflicts: true)
      expect(pkg.service_codes).to eq(%w[state_criminal drug_10_panel])
    end
  end

  describe "#remove" do
    let(:pkg) { build(%w[state_criminal county_criminal federal_criminal mvr]) }

    it "refuses to orphan dependents and explains what would be removed" do
      error = begin
        pkg.remove("state_criminal", policy)
      rescue Domain::ValidationError => e
        e
      end

      violation = error.violations.first
      expect(violation.type).to eq(:has_dependents)
      expect(violation.related_codes).to eq(%w[county_criminal federal_criminal])
      expect(violation.message).to eq(
        "Removing State Criminal Search will also remove County Criminal Search and Federal Criminal Search"
      )
      expect(pkg.service_codes.size).to eq(4)
    end

    it "removes dependents too when cascade is confirmed" do
      expect(pkg.remove("state_criminal", policy, cascade: true).service_codes).to eq(["mvr"])
    end

    it "removes a service nothing depends on" do
      expect(pkg.remove("county_criminal", policy).service_codes).to eq(%w[state_criminal federal_criminal mvr])
    end

    it "refuses to remove a service that is not selected" do
      expect(violation_types { pkg.remove("drug_5_panel", policy) }).to eq([:not_selected])
    end
  end

  describe "#revise" do
    it "replaces name and selection atomically, or not at all" do
      pkg = build(["mvr"])
      later = now + 60

      expect(violation_types { pkg.revise(name: "New", service_codes: ["county_criminal"], policy: policy, now: later) })
        .to eq([:missing_requirement])
      expect([pkg.name, pkg.service_codes, pkg.updated_at]).to eq(["Standard Hire Package", ["mvr"], now])

      pkg.revise(name: "New", service_codes: %w[mvr state_criminal], policy: policy, now: later)
      expect([pkg.name, pkg.service_codes, pkg.updated_at]).to eq(["New", %w[mvr state_criminal], later])
    end
  end

  describe "#duplicate" do
    it "copies the selection under a new id and a 'Copy of' name" do
      copy = build(["mvr"]).duplicate(new_id: "pkg-2", now: now + 1)
      expect([copy.id, copy.name, copy.service_codes]).to eq(["pkg-2", "Copy of Standard Hire Package", ["mvr"]])
    end
  end
end
