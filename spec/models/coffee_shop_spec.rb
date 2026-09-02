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

  describe "x/y aliasing" do
    it "reads and writes coordinate_x/coordinate_y through the x/y aliases" do
      shop = described_class.new(coordinate_x: 10.0, coordinate_y: 20.0)

      expect(shop.x).to eq(10.0)
      expect(shop.y).to eq(20.0)

      shop.x = 1.0
      shop.y = 2.0

      expect(shop.coordinate_x).to eq(1.0)
      expect(shop.coordinate_y).to eq(2.0)
    end
  end

  describe "validations" do
    it "is valid with a name and coordinates" do
      expect(build(:coffee_shop)).to be_valid
    end

    it "is invalid without a name" do
      shop = build(:coffee_shop, name: nil)

      expect(shop).not_to be_valid
      expect(shop.errors[:name]).to be_present
    end

    it "is invalid without coordinate_x" do
      shop = build(:coffee_shop, coordinate_x: nil)

      expect(shop).not_to be_valid
      expect(shop.errors[:coordinate_x]).to be_present
    end

    it "is invalid without coordinate_y" do
      shop = build(:coffee_shop, coordinate_y: nil)

      expect(shop).not_to be_valid
      expect(shop.errors[:coordinate_y]).to be_present
    end

    it "is valid without address or open_until" do
      shop = build(:coffee_shop, address: nil, open_until: nil)

      expect(shop).to be_valid
    end

    it "is invalid with the same name and coordinates as an existing shop" do
      create(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0)
      shop = build(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0)

      expect(shop).not_to be_valid
      expect(shop.errors[:name]).to be_present
    end

    it "is valid with the same name at different coordinates" do
      create(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0)
      shop = build(:coffee_shop, name: "Starbucks", coordinate_x: 3.0, coordinate_y: 4.0)

      expect(shop).to be_valid
    end

    it "is valid with the same coordinates under a different name" do
      create(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0)
      shop = build(:coffee_shop, name: "Peets", coordinate_x: 1.0, coordinate_y: 2.0)

      expect(shop).to be_valid
    end
  end

  describe "persistence" do
    it "saves and reloads all attributes, including the optional ones" do
      shop = create(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0,
                                   address: "123 Main St", open_until: "9pm")

      persisted = described_class.find(shop.id)

      expect(persisted).to have_attributes(
        name: "Starbucks",
        coordinate_x: 1.0,
        coordinate_y: 2.0,
        address: "123 Main St",
        open_until: "9pm"
      )
    end
  end
end
