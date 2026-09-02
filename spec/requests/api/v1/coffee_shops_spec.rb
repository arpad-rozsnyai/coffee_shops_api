require "rails_helper"

RSpec.describe "GET /api/v1/coffee_shops", type: :request do
  let(:repository) { instance_double(CoffeeShopRepository) }

  before do
    allow(CoffeeShopRepository).to receive(:new).and_return(repository)
  end

  def shop(name:, x:, y:)
    CoffeeShop.new(name: name, x: x, y: y)
  end

  context "with valid coordinates" do
    before do
      allow(repository).to receive(:all).and_return([
        shop(name: "Far", x: 10, y: 0),
        shop(name: "Near", x: 1, y: 0),
        shop(name: "Farthest", x: 20, y: 0),
        shop(name: "Mid", x: 3, y: 0)
      ])
    end

    it "returns the three nearest shops ordered nearest to farthest as a JSON:API document" do
      get "/api/v1/coffee_shops", params: { x: 0, y: 0 }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")

      data = response.parsed_body["data"]
      expect(data.size).to eq(3)
      expect(data.map { |resource| resource["attributes"]["name"] }).to eq(%w[Near Mid Far])
      expect(data.map { |resource| resource["type"] }.uniq).to eq(%w[coffee_shops])
      expect(data).to all(have_key("id"))
    end

    it "includes name, x, y, and a distance rounded to four decimal places" do
      get "/api/v1/coffee_shops", params: { x: 0, y: 0 }

      nearest = response.parsed_body["data"].first["attributes"]
      expect(nearest).to eq(
        "name" => "Near",
        "x" => 1.0,
        "y" => 0.0,
        "distance" => 1.0
      )
    end

    it "assigns the same deterministic id to the same shop across requests" do
      get "/api/v1/coffee_shops", params: { x: 0, y: 0 }
      first_id = response.parsed_body["data"].first["id"]

      get "/api/v1/coffee_shops", params: { x: 0, y: 0 }
      second_id = response.parsed_body["data"].first["id"]

      expect(first_id).to eq(second_id)
    end
  end

  context "with invalid coordinates" do
    it "returns a 400 JSON:API error document without hitting the repository" do
      allow(repository).to receive(:all)

      get "/api/v1/coffee_shops", params: { x: "not-a-number", y: "" }

      expect(response).to have_http_status(:bad_request)
      errors = response.parsed_body["errors"]
      expect(errors.map { |e| e["source"]["parameter"] }).to contain_exactly("x", "y")
      expect(errors).to all(include("status" => "400", "title" => "Invalid Parameter"))
      expect(repository).not_to have_received(:all)
    end

    it "returns 400 when a coordinate param is entirely missing" do
      allow(repository).to receive(:all)

      get "/api/v1/coffee_shops", params: { x: 0 }

      expect(response).to have_http_status(:bad_request)
      errors = response.parsed_body["errors"]
      expect(errors.map { |e| e["source"]["parameter"] }).to contain_exactly("y")
      expect(repository).not_to have_received(:all)
    end
  end

  context "when the remote CSV fetch fails" do
    it "returns a 503 JSON:API error document without exposing the internal exception" do
      allow(repository).to receive(:all).and_raise(CsvClient::RemoteDataSourceError, "connection refused to internal host")

      get "/api/v1/coffee_shops", params: { x: 0, y: 0 }

      expect(response).to have_http_status(:service_unavailable)
      body = response.body
      expect(body).not_to include("connection refused")
      expect(body).not_to include("CsvClient::RemoteDataSourceError")
      errors = response.parsed_body["errors"]
      expect(errors.first).to include(
        "status" => "503",
        "title" => "Data Source Unavailable",
        "detail" => "Coffee shop data is temporarily unavailable."
      )
    end
  end

  context "when the upstream CSV is structurally unusable" do
    it "returns a 503 JSON:API error document without exposing the internal exception" do
      allow(repository).to receive(:all).and_raise(CsvParser::ParseError, "Malformed CSV structure: unterminated quoted field")

      get "/api/v1/coffee_shops", params: { x: 0, y: 0 }

      expect(response).to have_http_status(:service_unavailable)
      body = response.body
      expect(body).not_to include("Malformed CSV structure")
      expect(body).not_to include("CsvParser::ParseError")
      errors = response.parsed_body["errors"]
      expect(errors.first).to include(
        "status" => "503",
        "title" => "Data Source Unavailable",
        "detail" => "Coffee shop data is temporarily unavailable."
      )
    end
  end

  context "when an unexpected programming error occurs" do
    it "propagates instead of being swallowed as a JSON:API error" do
      allow(repository).to receive(:all).and_raise(NoMethodError, "undefined method `foo' for nil")

      expect do
        get "/api/v1/coffee_shops", params: { x: 0, y: 0 }
      end.to raise_error(NoMethodError)
    end
  end
end
