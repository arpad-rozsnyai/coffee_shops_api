require "rails_helper"

RSpec.describe NearestCoffeeShopsFinder do
  let(:repository) { instance_double(CoffeeShopRepository) }
  let(:finder) { described_class.new(repository: repository) }

  def shop(name:, x:, y:)
    CoffeeShop.new(name: name, x: x, y: y)
  end

  describe "#call" do
    it "asks the repository for all shops" do
      allow(repository).to receive(:all).and_return([])

      finder.call(x: 0, y: 0)

      expect(repository).to have_received(:all)
    end

    it "orders results by ascending distance" do
      near = shop(name: "Near", x: 1, y: 0)
      mid = shop(name: "Mid", x: 3, y: 0)
      far = shop(name: "Far", x: 10, y: 0)
      allow(repository).to receive(:all).and_return([ far, near, mid ])

      results = finder.call(x: 0, y: 0)

      expect(results.map { |r| r[:coffee_shop].name }).to eq(%w[Near Mid Far])
    end

    it "returns at most three results when more shops exist" do
      shops = (1..5).map { |i| shop(name: "Shop#{i}", x: i, y: 0) }
      allow(repository).to receive(:all).and_return(shops.shuffle)

      results = finder.call(x: 0, y: 0)

      expect(results.size).to eq(3)
      expect(results.map { |r| r[:coffee_shop].name }).to eq(%w[Shop1 Shop2 Shop3])
    end

    it "returns fewer than three results when fewer shops exist" do
      allow(repository).to receive(:all).and_return([ shop(name: "Only", x: 5, y: 0) ])

      results = finder.call(x: 0, y: 0)

      expect(results.size).to eq(1)
      expect(results.first[:coffee_shop].name).to eq("Only")
    end

    it "returns an empty array for an empty dataset" do
      allow(repository).to receive(:all).and_return([])

      expect(finder.call(x: 0, y: 0)).to eq([])
    end

    it "pairs each result with the shop and its calculated distance" do
      target = shop(name: "Target", x: 3, y: 4)
      allow(repository).to receive(:all).and_return([ target ])

      results = finder.call(x: 0, y: 0)

      expect(results.first[:coffee_shop]).to eq(target)
      expect(results.first[:distance]).to eq(5.0)
    end

    it "sorts by full-precision distance, not a rounded distance" do
      # Both shops round to the same distance at 4 decimal places (1.0000), so a
      # naive implementation that rounded before sorting could tie or misorder
      # them; the unrounded distances are distinct and must be respected.
      closer = shop(name: "Closer", x: 1.00001, y: 0)
      farther = shop(name: "Farther", x: 1.00004, y: 0)
      allow(repository).to receive(:all).and_return([ farther, closer ])

      expect(closer.distance_to(0, 0).round(4)).to eq(farther.distance_to(0, 0).round(4))

      results = finder.call(x: 0, y: 0)

      expect(results.map { |r| r[:coffee_shop].name }).to eq(%w[Closer Farther])
    end

    it "breaks exact distance ties deterministically by shop name" do
      b_shop = shop(name: "B Shop", x: 1, y: 0)
      a_shop = shop(name: "A Shop", x: 0, y: 1)
      allow(repository).to receive(:all).and_return([ b_shop, a_shop ])

      results = finder.call(x: 0, y: 0)

      expect(results.map { |r| r[:coffee_shop].name }).to eq([ "A Shop", "B Shop" ])
    end
  end
end
