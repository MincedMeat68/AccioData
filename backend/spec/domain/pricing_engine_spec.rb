# frozen_string_literal: true

# The worked examples from the ASSESSMENT.md appendix are the acceptance
# criteria for pricing.
RSpec.describe Domain::Pricing::PricingEngine do
  subject(:engine) { described_class.new(TestSupport.catalog) }

  def quote(*codes) = engine.quote(codes.map(&:to_s))
  def discounts(q) = q.discounts.to_h { |d| [d.code, d.amount.cents] }

  let(:all_criminal) { %i[state_criminal county_criminal federal_criminal national_criminal] }
  let(:all_verification) { %i[employment_verification education_verification license_verification] }

  it "Example 1: three services, no discounts ($95.00)" do
    q = quote(:state_criminal, :employment_verification, :drug_5_panel)

    expect(q.subtotal.cents).to eq(9500)
    expect(q.discounts).to be_empty
    expect(q.total.cents).to eq(9500)
  end

  it "Example 2: five services get 10% volume discount ($121.50)" do
    q = quote(:state_criminal, :county_criminal, :national_criminal, :employment_verification, :mvr)

    expect(q.subtotal.cents).to eq(13_500)
    expect(discounts(q)).to eq("volume" => 1350)
    expect(q.discounts.first.label).to eq("Volume Discount (10% for 5+ services)")
    expect(q.total.cents).to eq(12_150)
  end

  it "Example 3: eight services stack 15% volume with both bundles ($160.50)" do
    q = quote(*all_criminal, *all_verification, :mvr)

    expect(q.subtotal.cents).to eq(23_000)
    expect(discounts(q)).to eq("volume" => 3450, "criminal_bundle" => 2000, "verification_bundle" => 1500)
    expect(q.total.cents).to eq(16_050)
  end

  # The spec's Example 4 ("all 10 services", $254.00) includes both drug
  # panels, which the conflict rule forbids. The engine prices any list it is
  # given, so the arithmetic is checked here; the conflict is the policy's job.
  it "Example 4 arithmetic: all ten services price to $254.00" do
    q = quote(*TestSupport.catalog.services.map(&:code))

    expect(q.subtotal.cents).to eq(34_000)
    expect(discounts(q)).to eq("volume" => 5100, "criminal_bundle" => 2000, "verification_bundle" => 1500)
    expect(q.total.cents).to eq(25_400)
  end

  it "prices the largest valid package (all but 5-Panel) at $215.75" do
    q = quote(*all_criminal, *all_verification, :mvr, :drug_10_panel)

    expect(q.subtotal.cents).to eq(29_500)
    expect(q.total.cents).to eq(21_575)
  end

  describe "volume tiers" do
    it "gives nothing at 4 services" do
      expect(discounts(quote(:state_criminal, :county_criminal, :federal_criminal, :mvr))).to be_empty
    end

    it "gives 10% at 7 services and 15% (not 25%) at 8" do
      seven = quote(:state_criminal, :county_criminal, :federal_criminal, *all_verification, :mvr)
      expect(discounts(seven)["volume"]).to eq(seven.subtotal.percent(10).cents)

      eight = quote(:state_criminal, :county_criminal, :federal_criminal, *all_verification, :mvr, :drug_5_panel)
      expect(discounts(eight)["volume"]).to eq(eight.subtotal.percent(15).cents)
    end
  end

  it "applies a bundle without the volume discount when under 5 services" do
    q = quote(*all_verification)

    expect(discounts(q)).to eq("verification_bundle" => 1500)
    expect(q.total.cents).to eq(10_000 - 1500)
  end

  it "itemizes every service in selection order" do
    q = quote(:mvr, :state_criminal)

    expect(q.line_items.map(&:service_code)).to eq(%w[mvr state_criminal])
    expect(q.line_items.map { |li| li.price.cents }).to eq([2000, 1500])
  end

  it "prices an empty selection at zero" do
    q = quote
    expect([q.subtotal.cents, q.total.cents, q.discounts]).to eq([0, 0, []])
  end
end
