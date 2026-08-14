require "rails_helper"

RSpec.describe CoffeeShops do
  describe ".csv_url" do
    context "when COFFEE_SHOPS_CSV_URL is not set" do
      around do |example|
        original = ENV.delete("COFFEE_SHOPS_CSV_URL")
        example.run
      ensure
        ENV["COFFEE_SHOPS_CSV_URL"] = original
      end

      it "returns the default challenge URL" do
        expect(described_class.csv_url).to eq(CoffeeShops::DEFAULT_CSV_URL)
      end

      it "returns a non-empty string" do
        expect(described_class.csv_url).not_to be_empty
      end
    end

    context "when COFFEE_SHOPS_CSV_URL is set" do
      around do |example|
        original = ENV["COFFEE_SHOPS_CSV_URL"]
        ENV["COFFEE_SHOPS_CSV_URL"] = "https://example.com/custom_shops.csv"
        example.run
      ensure
        ENV["COFFEE_SHOPS_CSV_URL"] = original
      end

      it "returns the env var value instead of the default" do
        expect(described_class.csv_url).to eq("https://example.com/custom_shops.csv")
      end

      it "does not return the default URL" do
        expect(described_class.csv_url).not_to eq(CoffeeShops::DEFAULT_CSV_URL)
      end
    end
  end
end
