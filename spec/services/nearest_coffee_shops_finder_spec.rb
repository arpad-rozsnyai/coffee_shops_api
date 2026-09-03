require "rails_helper"

RSpec.describe NearestCoffeeShopsFinder do
  let(:finder) { described_class.new(repository: CoffeeShop) }

  describe "#call" do
    it "orders results by ascending distance" do
      create(:coffee_shop, name: "Far", coordinate_x: 10, coordinate_y: 0)
      create(:coffee_shop, name: "Near", coordinate_x: 1, coordinate_y: 0)
      create(:coffee_shop, name: "Mid", coordinate_x: 3, coordinate_y: 0)

      results = finder.call(x: 0, y: 0)

      expect(results.map { |r| r[:coffee_shop].name }).to eq(%w[Near Mid Far])
    end

    it "returns at most the default limit of results when more shops exist and no limit is given" do
      (1..CoffeeShops::DEFAULT_LIMIT + 1).each { |i| create(:coffee_shop, name: "Shop#{i}", coordinate_x: i, coordinate_y: 0) }

      results = finder.call(x: 0, y: 0)

      expect(results.size).to eq(CoffeeShops::DEFAULT_LIMIT)
      expect(results.map { |r| r[:coffee_shop].name }).to eq((1..CoffeeShops::DEFAULT_LIMIT).map { |i| "Shop#{i}" })
    end

    it "honors a custom limit" do
      (1..5).each { |i| create(:coffee_shop, name: "Shop#{i}", coordinate_x: i, coordinate_y: 0) }

      results = finder.call(x: 0, y: 0, limit: 2)

      expect(results.size).to eq(2)
      expect(results.map { |r| r[:coffee_shop].name }).to eq(%w[Shop1 Shop2])
    end

    it "falls back to the default limit when limit is explicitly nil, rather than returning every row" do
      (1..5).each { |i| create(:coffee_shop, name: "Shop#{i}", coordinate_x: i, coordinate_y: 0) }

      results = finder.call(x: 0, y: 0, limit: nil)

      expect(results.size).to eq(CoffeeShops::DEFAULT_LIMIT)
    end

    it "returns fewer results than the limit when fewer shops exist" do
      create(:coffee_shop, name: "Only", coordinate_x: 5, coordinate_y: 0)

      results = finder.call(x: 0, y: 0)

      expect(results.size).to eq(1)
      expect(results.first[:coffee_shop].name).to eq("Only")
    end

    it "returns an empty array for an empty dataset" do
      expect(finder.call(x: 0, y: 0)).to eq([])
    end

    it "pairs each result with the shop and its calculated distance" do
      create(:coffee_shop, name: "Target", coordinate_x: 3, coordinate_y: 4)

      results = finder.call(x: 0, y: 0)

      expect(results.first[:coffee_shop].name).to eq("Target")
      expect(results.first[:distance]).to eq(5.0)
    end

    it "sorts by full-precision distance, not a rounded distance" do
      # Both shops round to the same distance at 4 decimal places (1.0000), so a naive
      # implementation that rounded before sorting could tie or misorder them; the
      # unrounded distances computed by SQL are distinct and must be respected.
      create(:coffee_shop, name: "Farther", coordinate_x: 1.00004, coordinate_y: 0)
      create(:coffee_shop, name: "Closer", coordinate_x: 1.00001, coordinate_y: 0)

      results = finder.call(x: 0, y: 0)

      expect(results.map { |r| r[:coffee_shop].name }).to eq(%w[Closer Farther])
    end

    it "breaks exact distance ties deterministically by shop name" do
      create(:coffee_shop, name: "B Shop", coordinate_x: 1, coordinate_y: 0)
      create(:coffee_shop, name: "A Shop", coordinate_x: 0, coordinate_y: 1)

      results = finder.call(x: 0, y: 0)

      expect(results.map { |r| r[:coffee_shop].name }).to eq([ "A Shop", "B Shop" ])
    end

    it "restricts results to shops matching a case-insensitive partial name, when given" do
      create(:coffee_shop, name: "Blue Bottle Coffee", coordinate_x: 1, coordinate_y: 0)
      create(:coffee_shop, name: "Starbucks", coordinate_x: 2, coordinate_y: 0)
      create(:coffee_shop, name: "Blue Sky Coffee", coordinate_x: 10, coordinate_y: 0)

      results = finder.call(x: 0, y: 0, name: "blue")

      expect(results.map { |r| r[:coffee_shop].name }).to eq([ "Blue Bottle Coffee", "Blue Sky Coffee" ])
    end

    it "returns an empty array when the name filter matches nothing" do
      create(:coffee_shop, name: "Starbucks", coordinate_x: 1, coordinate_y: 0)

      expect(finder.call(x: 0, y: 0, name: "nonexistent")).to eq([])
    end

    it "does not filter by name when name is omitted" do
      create(:coffee_shop, name: "Starbucks", coordinate_x: 1, coordinate_y: 0)
      create(:coffee_shop, name: "Blue Bottle Coffee", coordinate_x: 2, coordinate_y: 0)

      results = finder.call(x: 0, y: 0)

      expect(results.map { |r| r[:coffee_shop].name }).to eq([ "Starbucks", "Blue Bottle Coffee" ])
    end
  end
end
