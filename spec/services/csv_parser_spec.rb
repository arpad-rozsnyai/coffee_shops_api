require "rails_helper"

RSpec.describe CsvParser do
  def fixture(name)
    Rails.root.join("spec/fixtures/files/coffee_shops", name).read
  end

  describe ".parse" do
    context "with a fully valid CSV" do
      it "returns a CoffeeShop for every row" do
        shops = described_class.parse(fixture("valid.csv"))

        expect(shops.size).to eq(3)
        expect(shops).to all(be_a(CoffeeShop))
        expect(shops.map(&:name)).to eq([ "Starbucks Seattle", "Starbucks Seattle2", "Starbucks SF" ])
      end

      it "exposes numeric x/y values" do
        shops = described_class.parse(fixture("valid.csv"))

        expect(shops.first.x).to eq(47.6)
        expect(shops.first.y).to eq(-122.3)
      end
    end

    context "with a mix of valid and malformed rows" do
      it "skips malformed rows and keeps valid ones" do
        shops = described_class.parse(fixture("mixed.csv"))

        expect(shops.map(&:name)).to eq(
          [ "Starbucks Seattle", "Valid Negative", "Valid Decimal" ]
        )
      end

      it "rejects rows with a blank name" do
        shops = described_class.parse(fixture("mixed.csv"))

        expect(shops.map(&:name)).not_to include("", nil)
      end

      it "rejects rows with a missing coordinate" do
        shops = described_class.parse(fixture("mixed.csv"))

        expect(shops.map(&:name)).not_to include("Blank Coordinates", "Missing Trailing Field")
      end

      it "rejects rows with a non-numeric coordinate" do
        shops = described_class.parse(fixture("mixed.csv"))

        expect(shops.map(&:name)).not_to include("Non Numeric")
      end

      it "accepts valid negative and decimal coordinates" do
        shops = described_class.parse(fixture("mixed.csv"))

        negative = shops.find { |s| s.name == "Valid Negative" }
        decimal = shops.find { |s| s.name == "Valid Decimal" }

        expect(negative.x).to eq(-122.4)
        expect(negative.y).to eq(47.6)
        expect(decimal.x).to eq(12.3456)
        expect(decimal.y).to eq(-98.7654)
      end
    end

    context "with an empty dataset" do
      it "returns an empty array without raising" do
        expect(described_class.parse(fixture("empty.csv"))).to eq([])
      end

      it "returns an empty array for a completely empty input, without raising" do
        expect(described_class.parse("")).to eq([])
      end
    end

    context "with structurally malformed CSV" do
      it "raises CsvParser::ParseError instead of returning an empty dataset" do
        expect { described_class.parse(fixture("malformed.csv")) }
          .to raise_error(CsvParser::ParseError, /malformed csv structure/i)
      end
    end
  end
end
