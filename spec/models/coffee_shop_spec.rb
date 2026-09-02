require "rails_helper"

RSpec.describe CoffeeShop do
  describe "#distance_to" do
    it "returns 0 for identical coordinates" do
      shop = described_class.new(name: "Origin", x: 1.5, y: -2.5)

      expect(shop.distance_to(1.5, -2.5)).to eq(0)
    end

    it "returns the Euclidean distance between two points" do
      shop = described_class.new(name: "Origin", x: 0, y: 0)

      expect(shop.distance_to(3, 4)).to eq(5.0)
    end

    it "returns full precision without rounding" do
      shop = described_class.new(name: "Origin", x: 0, y: 0)

      expect(shop.distance_to(1, 1)).to eq(Math.hypot(1, 1))
    end
  end

  describe "attribute exposure" do
    it "exposes the values it was initialized with" do
      shop = described_class.new(name: "Starbucks", x: 47.6, y: -122.4)

      expect(shop.name).to eq("Starbucks")
      expect(shop.x).to eq(47.6)
      expect(shop.y).to eq(-122.4)
    end
  end
end
