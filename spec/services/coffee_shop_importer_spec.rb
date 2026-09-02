require "rails_helper"

RSpec.describe CoffeeShopImporter do
  let(:client) { instance_double(CsvClient) }
  let(:parser) { class_double(CsvParser) }
  let(:importer) { described_class.new(client: client, parser: parser) }
  let(:raw_csv) { "Starbucks,47.6,-122.4\n" }

  before { allow(client).to receive(:fetch).and_return(raw_csv) }

  describe "#call" do
    it "persists shops parsed from the fetched CSV" do
      shops = [ CoffeeShop.new(name: "Starbucks", x: 47.6, y: -122.4) ]
      allow(parser).to receive(:parse).with(raw_csv).and_return(shops)

      expect { importer.call }.to change(CoffeeShop, :count).by(1)
      expect(CoffeeShop.sole.name).to eq("Starbucks")
    end

    it "returns a result for each parsed shop, marking new shops as imported" do
      shops = [ CoffeeShop.new(name: "A", x: 1, y: 1), CoffeeShop.new(name: "B", x: 2, y: 2) ]
      allow(parser).to receive(:parse).and_return(shops)

      results = importer.call

      expect(results.map { |result| result[:coffee_shop].name }).to eq(%w[A B])
      expect(results).to all(include(imported: true))
    end

    it "leaves unrelated existing rows in place and adds the new ones" do
      create(:coffee_shop, name: "Existing", coordinate_x: 9.0, coordinate_y: 9.0)
      shops = [ CoffeeShop.new(name: "Fresh", x: 1, y: 1) ]
      allow(parser).to receive(:parse).and_return(shops)

      expect { importer.call }.to change(CoffeeShop, :count).by(1)
      expect(CoffeeShop.pluck(:name)).to contain_exactly("Existing", "Fresh")
    end

    it "skips a shop that already exists (same name and coordinates) rather than duplicating it" do
      create(:coffee_shop, name: "Starbucks", coordinate_x: 47.6, coordinate_y: -122.4)
      shops = [ CoffeeShop.new(name: "Starbucks", x: 47.6, y: -122.4) ]
      allow(parser).to receive(:parse).and_return(shops)

      expect { importer.call }.not_to change(CoffeeShop, :count)
    end

    it "marks a duplicate shop's result as not imported" do
      create(:coffee_shop, name: "Starbucks", coordinate_x: 47.6, coordinate_y: -122.4)
      shops = [
        CoffeeShop.new(name: "Starbucks", x: 47.6, y: -122.4),
        CoffeeShop.new(name: "Peets", x: 1, y: 1)
      ]
      allow(parser).to receive(:parse).and_return(shops)

      results = importer.call

      expect(results.find { |result| result[:coffee_shop].name == "Starbucks" }[:imported]).to be(false)
      expect(results.find { |result| result[:coffee_shop].name == "Peets" }[:imported]).to be(true)
    end

    it "raises rather than silently skipping a shop that is invalid for a reason other than already existing" do
      shops = [ CoffeeShop.new(name: nil, x: 1, y: 1) ]
      allow(parser).to receive(:parse).and_return(shops)

      expect { importer.call }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "imports nothing for an empty feed" do
      allow(parser).to receive(:parse).and_return([])

      expect { importer.call }.not_to change(CoffeeShop, :count)
    end

    it "propagates CsvClient::RemoteDataSourceError raised by the client" do
      allow(client).to receive(:fetch).and_raise(CsvClient::RemoteDataSourceError, "boom")

      expect { importer.call }.to raise_error(CsvClient::RemoteDataSourceError, "boom")
    end

    it "propagates CsvParser::ParseError raised by the parser" do
      allow(parser).to receive(:parse).and_raise(CsvParser::ParseError, "bad csv")

      expect { importer.call }.to raise_error(CsvParser::ParseError, "bad csv")
    end

    it "leaves existing rows untouched when the client raises" do
      create(:coffee_shop, name: "Stays")
      allow(client).to receive(:fetch).and_raise(CsvClient::RemoteDataSourceError, "boom")

      expect { importer.call }.to raise_error(CsvClient::RemoteDataSourceError)
      expect(CoffeeShop.pluck(:name)).to eq([ "Stays" ])
    end
  end

  describe "default collaborators" do
    it "defaults to a CsvClient instance and the CsvParser module" do
      importer = described_class.new

      expect(importer.send(:client)).to be_a(CsvClient)
      expect(importer.send(:parser)).to eq(CsvParser)
    end
  end
end
