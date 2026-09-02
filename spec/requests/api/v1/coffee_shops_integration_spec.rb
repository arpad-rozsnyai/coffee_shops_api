require "rails_helper"

RSpec.describe "GET /api/v1/coffee_shops (full stack)", type: :request do
  let(:csv_url) { CoffeeShops.csv_url }

  def fixture(name)
    Rails.root.join("spec/fixtures/files/coffee_shops", name).read
  end

  def stub_csv(body)
    stub_request(:get, csv_url).to_return(status: 200, body: body)
  end

  context "with a CSV feed matching the challenge reference dataset, plus malformed rows and an extra farther shop" do
    before { stub_csv(fixture("integration_mixed.csv")) }

    it "returns the three nearest shops ordered nearest to farthest, matching the reference case" do
      get "/api/v1/coffee_shops", params: { x: 47.6, y: -122.4 }

      expect(response).to have_http_status(:ok)
      names = response.parsed_body["data"].map { |resource| resource["attributes"]["name"] }
      expect(names).to eq([ "Starbucks Seattle2", "Starbucks Seattle", "Starbucks SF" ])
    end

    it "makes exactly one HTTP request, to the configured CSV source, with no other network access" do
      get "/api/v1/coffee_shops", params: { x: 47.6, y: -122.4 }

      expect(WebMock).to have_requested(:get, csv_url).once
    end
  end

  context "with a shop whose distance does not terminate at four decimal places" do
    before { stub_csv(fixture("integration_irrational.csv")) }

    it "rounds the distance attribute to four decimal places" do
      get "/api/v1/coffee_shops", params: { x: 0, y: 0 }

      distance = response.parsed_body["data"].first["attributes"]["distance"]
      expect(distance).to eq(1.4142)
    end
  end
end
