# frozen_string_literal: true

RSpec.describe Domain::Packaging::SelectionPolicy do
  subject(:policy) { described_class.new(TestSupport.catalog) }

  def status_of(codes, code) = policy.availability(codes).find { |a| a.service_code == code }

  describe "dependencies (Flow 2)" do
    it "refuses County Criminal before State Criminal, with the spec's message" do
      problems = policy.violations_for_add([], "county_criminal")

      expect(problems.map(&:type)).to eq([:missing_requirement])
      expect(problems.first.message).to eq("County Criminal Search requires State Criminal Search to be added first")
      expect(problems.first.related_codes).to eq(["state_criminal"])
    end

    it "marks County and Federal blocked until State is selected, then available" do
      expect(status_of([], "county_criminal").status).to eq(:blocked)
      expect(status_of([], "federal_criminal").status).to eq(:blocked)

      expect(status_of(["state_criminal"], "county_criminal").status).to eq(:available)
      expect(status_of(["state_criminal"], "federal_criminal").status).to eq(:available)
    end

    it "treats National Criminal as standalone" do
      expect(policy.violations_for_add([], "national_criminal")).to be_empty
    end

    it "reports a saved selection that is missing a prerequisite" do
      expect(policy.violations(["federal_criminal"]).map(&:type)).to eq([:missing_requirement])
    end
  end

  describe "conflicts (Flow 3)" do
    it "refuses 10-Panel while 5-Panel is selected, with the spec's message" do
      problems = policy.violations_for_add(["drug_5_panel"], "drug_10_panel")

      expect(problems.map(&:type)).to eq([:conflict])
      expect(problems.first.message)
        .to eq("Drug Test (10-Panel) conflicts with Drug Test (5-Panel) - the 10-Panel includes all 5-Panel tests")
    end

    it "is symmetric: 5-Panel conflicts with a selected 10-Panel" do
      expect(status_of(["drug_10_panel"], "drug_5_panel").status).to eq(:conflict)
    end

    it "offers replacement only in the superseding direction" do
      expect(policy.replaceable_by(["drug_5_panel"], "drug_10_panel")).to eq(["drug_5_panel"])
      expect(policy.replaceable_by(["drug_10_panel"], "drug_5_panel")).to be_empty
    end

    it "reports both panels in one selection" do
      expect(policy.violations(%w[drug_5_panel drug_10_panel]).map(&:type)).to eq([:conflict])
    end
  end

  describe "#removal_cascade" do
    it "lists every selected dependent of a prerequisite, in selection order" do
      codes = %w[state_criminal federal_criminal mvr county_criminal]
      expect(policy.removal_cascade(codes, "state_criminal")).to eq(%w[federal_criminal county_criminal])
    end

    it "is empty when nothing selected depends on the service" do
      expect(policy.removal_cascade(%w[state_criminal mvr], "state_criminal")).to be_empty
      expect(policy.removal_cascade(%w[state_criminal county_criminal], "county_criminal")).to be_empty
    end

    it "is exposed on selected services in the availability report" do
      expect(status_of(%w[state_criminal county_criminal], "state_criminal").removal_cascade).to eq(["county_criminal"])
    end
  end

  it "rejects unknown and duplicate codes" do
    expect(policy.violations(["nope"]).map(&:type)).to eq([:unknown_service])
    expect(policy.violations(%w[mvr mvr]).map(&:type)).to eq([:duplicate_service])
  end

  it "reports already-selected services when adding" do
    expect(policy.violations_for_add(["mvr"], "mvr").map(&:type)).to eq([:already_selected])
  end
end
