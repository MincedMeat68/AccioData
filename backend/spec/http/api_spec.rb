# frozen_string_literal: true

require "rack/test"

RSpec.describe Http::Api do
  include Rack::Test::Methods

  let(:app) do
    Class.new(described_class).tap { |api| api.set :container, Container.new(db: TestSupport.database) }
  end

  def json_body = JSON.parse(last_response.body)
  def post_json(path, data) = post(path, JSON.generate(data), "CONTENT_TYPE" => "application/json")
  def put_json(path, data) = put(path, JSON.generate(data), "CONTENT_TYPE" => "application/json")

  describe "GET /api/catalog" do
    it "returns services, rules as data, discounts and priced templates" do
      get "/api/catalog"

      expect(last_response.status).to eq(200)
      expect(json_body["services"].size).to eq(10)
      expect(json_body["rules"]["requirements"]).to include("service" => "county_criminal", "requires" => "state_criminal")
      expect(json_body["rules"]["conflicts"].first).to include("service" => "drug_10_panel", "supersedes" => true)
      expect(json_body["discounts"].map { |d| d["type"] }).to eq(%w[volume bundle bundle])
      expect(json_body["templates"].map { |t| t["quote"]["total_cents"] }).to eq([9500, 18_250, 21_575])
    end
  end

  it "GET /api/services lists services with prices" do
    get "/api/services"
    expect(json_body.first).to include("code" => "state_criminal", "price_cents" => 1500, "category" => "criminal")
  end

  describe "POST /api/packages/evaluate" do
    it "returns quote, violations and availability" do
      post_json "/api/packages/evaluate", service_codes: %w[state_criminal county_criminal federal_criminal
                                                            national_criminal employment_verification
                                                            education_verification license_verification mvr]

      expect(last_response.status).to eq(200)
      expect(json_body["valid"]).to be(true)
      expect(json_body["quote"]).to include("subtotal_cents" => 23_000, "total_cents" => 16_050)
      expect(json_body["quote"]["discounts"].map { |d| d["amount_cents"] }).to eq([3450, 2000, 1500])
      state = json_body["availability"].find { |a| a["service_code"] == "state_criminal" }
      expect(state["removal_cascade"]).to eq(%w[county_criminal federal_criminal])
    end

    it "400s on malformed input" do
      post "/api/packages/evaluate", "{not json", "CONTENT_TYPE" => "application/json"
      expect(last_response.status).to eq(400)

      post_json "/api/packages/evaluate", service_codes: "mvr"
      expect(json_body["error"]["message"]).to eq("service_codes must be an array of strings")
    end
  end

  it "POST /api/packages/price and /validate answer separately" do
    post_json "/api/packages/price", service_codes: ["mvr"]
    expect(json_body["total_cents"]).to eq(2000)

    post_json "/api/packages/validate", service_codes: ["county_criminal"]
    expect(json_body["valid"]).to be(false)
    expect(json_body["violations"].first["type"]).to eq("missing_requirement")
  end

  describe "package lifecycle" do
    it "creates, loads latest, updates, duplicates, lists and deletes" do
      get "/api/packages/latest"
      expect(last_response.status).to eq(204)

      post_json "/api/packages", name: "Standard Hire Package",
                                 service_codes: %w[state_criminal employment_verification drug_5_panel]
      expect(last_response.status).to eq(201)
      id = json_body["id"]
      expect(json_body["quote"]["total_cents"]).to eq(9500)

      get "/api/packages/latest"
      expect(json_body["id"]).to eq(id)

      put_json "/api/packages/#{id}", name: "Renamed", service_codes: %w[state_criminal county_criminal]
      expect(last_response.status).to eq(200)
      expect(json_body).to include("name" => "Renamed", "service_codes" => %w[state_criminal county_criminal])

      post_json "/api/packages/#{id}/duplicate", {}
      expect(last_response.status).to eq(201)
      copy_id = json_body["id"]
      expect(json_body["name"]).to eq("Copy of Renamed")

      get "/api/packages"
      expect(json_body.map { |p| p["id"] }).to contain_exactly(id, copy_id)

      delete "/api/packages/#{id}"
      expect(last_response.status).to eq(204)
      get "/api/packages/#{id}"
      expect(last_response.status).to eq(404)
      expect(json_body["error"]["code"]).to eq("not_found")
    end

    it "422s with every violation when the package breaks rules" do
      post_json "/api/packages", name: "", service_codes: %w[county_criminal drug_5_panel drug_10_panel]

      expect(last_response.status).to eq(422)
      expect(json_body["error"]["code"]).to eq("validation_failed")
      expect(json_body["error"]["violations"].map { |v| v["type"] })
        .to contain_exactly("invalid_name", "missing_requirement", "conflict")
    end
  end

  it "404s unknown routes with the error envelope" do
    get "/api/nope"
    expect(last_response.status).to eq(404)
    expect(json_body["error"]["code"]).to eq("not_found")
  end
end
