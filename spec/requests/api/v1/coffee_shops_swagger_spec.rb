require "swagger_helper"

RSpec.describe "api/v1/coffee_shops", type: :request do
  path "/api/v1/coffee_shops" do
    get "Finds the three nearest coffee shops to a coordinate" do
      tags "Coffee Shops"
      produces "application/json"
      description "Fetches coffee shop data from the configured CSV source and returns the three " \
                   "nearest shops to the given X/Y coordinate, ordered nearest to farthest, as a " \
                   "JSON:API document."

      parameter name: :x, in: :query, schema: { type: :number, format: :float },
                required: true, description: "User's X coordinate", example: 47.6
      parameter name: :y, in: :query, schema: { type: :number, format: :float },
                required: true, description: "User's Y coordinate", example: -122.4

      let(:csv_url) { CoffeeShops.csv_url }

      def fixture(name)
        Rails.root.join("spec/fixtures/files/coffee_shops", name).read
      end

      response "200", "three nearest coffee shops, nearest first" do
        schema type: :object,
          properties: {
            data: {
              type: :array,
              minItems: 3,
              maxItems: 3,
              items: {
                type: :object,
                properties: {
                  id: {
                    type: :string,
                    description: "Deterministic id derived from the shop's name/x/y",
                    example: "3f2e1a0b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4f"
                  },
                  type: { type: :string, example: "coffee_shops" },
                  attributes: {
                    type: :object,
                    properties: {
                      name: { type: :string, example: "Starbucks Seattle2" },
                      x: { type: :number, example: 47.6109 },
                      y: { type: :number, example: -122.4 },
                      distance: { type: :number, description: "Rounded to 4 decimal places", example: 0.0109 }
                    },
                    required: %w[name x y distance]
                  }
                },
                required: %w[id type attributes]
              }
            }
          },
          required: %w[data]

        let(:x) { 47.6 }
        let(:y) { -122.4 }

        before { stub_request(:get, csv_url).to_return(status: 200, body: fixture("integration_mixed.csv")) }

        run_test! do |response|
          names = JSON.parse(response.body)["data"].map { |resource| resource["attributes"]["name"] }
          expect(names).to eq([ "Starbucks Seattle2", "Starbucks Seattle", "Starbucks SF" ])
        end
      end

      response "400", "x and/or y is missing or not a valid number" do
        schema type: :object,
          properties: {
            errors: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  status: { type: :string, example: "400" },
                  title: { type: :string, example: "Invalid Parameter" },
                  detail: { type: :string, example: "is not a valid number" },
                  source: {
                    type: :object,
                    properties: { parameter: { type: :string, example: "x" } },
                    required: %w[parameter]
                  }
                },
                required: %w[status title detail source]
              }
            }
          },
          required: %w[errors]

        let(:x) { "not-a-number" }
        let(:y) { "" }

        run_test! do |response|
          parameters = JSON.parse(response.body)["errors"].map { |error| error["source"]["parameter"] }
          expect(parameters).to contain_exactly("x", "y")
        end
      end

      response "503", "the coffee shop CSV source is unavailable or unusable" do
        schema type: :object,
          properties: {
            errors: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  status: { type: :string, example: "503" },
                  title: { type: :string, example: "Data Source Unavailable" },
                  detail: { type: :string, example: "Coffee shop data is temporarily unavailable." }
                },
                required: %w[status title detail]
              }
            }
          },
          required: %w[errors]

        let(:x) { 47.6 }
        let(:y) { -122.4 }

        before { stub_request(:get, csv_url).to_return(status: 500) }

        run_test!
      end
    end
  end
end
