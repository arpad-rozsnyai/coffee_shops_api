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

    it "is invalid with the same name and coordinates as an existing shop (same derived slug)" do
      create(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0)
      shop = build(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0)

      expect(shop).not_to be_valid
      expect(shop.errors[:slug]).to be_present
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

  describe "slug" do
    it "is generated from the name and coordinates on creation" do
      shop = create(:coffee_shop, name: "Starbucks Seattle", coordinate_x: 47.5809, coordinate_y: -122.316)

      expect(shop.slug).to eq("starbucks-seattle-47-5809-neg122-316")
    end

    it "ignores any slug explicitly assigned before creation and derives its own" do
      shop = create(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0, slug: "whatever-i-want")

      expect(shop.slug).not_to eq("whatever-i-want")
      expect(shop.slug).to eq("starbucks-1-0-2-0")
    end

    it "is not blank even when the name is made entirely of characters parameterize strips" do
      shop = create(:coffee_shop, name: "!!!", coordinate_x: 1.0, coordinate_y: 2.0)

      expect(shop.slug).to be_present
      expect(shop.slug).to eq("1-0-2-0")
    end

    it "transliterates unicode names rather than dropping them" do
      shop = create(:coffee_shop, name: "Café Central", coordinate_x: 1.0, coordinate_y: 2.0)

      expect(shop.slug).to eq("cafe-central-1-0-2-0")
    end

    it "does not raise and stays blank-safe when coordinates are nil (invalid, but must not error)" do
      shop = build(:coffee_shop, name: "Starbucks", coordinate_x: nil, coordinate_y: nil)

      expect { shop.valid? }.not_to raise_error
      expect(shop).not_to be_valid
    end

    it "distinguishes coordinates from their sign-flipped counterparts" do
      positive = create(:coffee_shop, name: "Twin", coordinate_x: 1.0, coordinate_y: 1.0)
      negative_x = create(:coffee_shop, name: "Twin", coordinate_x: -1.0, coordinate_y: 1.0)
      negative_y = create(:coffee_shop, name: "Twin", coordinate_x: 1.0, coordinate_y: -1.0)
      negative_both = create(:coffee_shop, name: "Twin", coordinate_x: -1.0, coordinate_y: -1.0)

      slugs = [ positive, negative_x, negative_y, negative_both ].map(&:slug)

      expect(slugs.uniq).to eq(slugs)
    end

    it "raises a database-level not-null violation if a row is inserted without going through the model" do
      expect {
        ActiveRecord::Base.connection.execute(
          "INSERT INTO coffee_shops (name, coordinate_x, coordinate_y, created_at, updated_at) " \
          "VALUES ('Bypassed', 1.0, 2.0, NOW(), NOW())"
        )
      }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "cannot be changed after creation, even via an explicit update" do
      shop = create(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0)
      original_slug = shop.slug

      expect { shop.update(slug: "hand-rolled-slug") }.to raise_error(ActiveRecord::ReadonlyAttributeError)
      expect(shop.reload.slug).to eq(original_slug)
    end

    it "stays the same across unrelated updates" do
      shop = create(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0)
      original_slug = shop.slug

      shop.update!(open_until: "10pm")

      expect(shop.reload.slug).to eq(original_slug)
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
