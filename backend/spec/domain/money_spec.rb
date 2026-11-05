# frozen_string_literal: true

RSpec.describe Domain::Money do
  let(:money) { described_class.from_cents(13_500) }

  it "adds and subtracts exactly" do
    expect((money + described_class.from_cents(1)).cents).to eq(13_501)
    expect((money - described_class.from_cents(13_501)).cents).to eq(-1)
  end

  it "takes a percentage rounding half-up to the cent" do
    expect(money.percent(10).cents).to eq(1350)
    expect(described_class.from_cents(5).percent(10).cents).to eq(1)  # 0.5 -> 1
    expect(described_class.from_cents(4).percent(10).cents).to eq(0)  # 0.4 -> 0
  end

  it "formats as dollars" do
    expect(money.to_s).to eq("$135.00")
    expect(described_class.from_cents(-3450).to_s).to eq("-$34.50")
  end

  it "clamps negatives to zero" do
    expect(described_class.from_cents(-1).clamp_at_zero).to eq(described_class.zero)
  end

  it "is a value object" do
    expect(described_class.from_cents(100)).to eq(described_class.from_cents(100))
    expect(money).to be_frozen
  end
end
