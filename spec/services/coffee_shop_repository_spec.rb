require "rails_helper"

RSpec.describe CoffeeShopRepository do
  let(:client) { instance_double(CsvClient) }
  let(:parser) { class_double(CsvParser) }
  let(:repository) { described_class.new(client: client, parser: parser) }

  describe "#all" do
    it "fetches raw CSV via the client and returns the parser's result" do
      raw_csv = "Name,X,Y\nStarbucks,47.6,-122.4\n"
      shops = [ instance_double(CoffeeShop) ]

      allow(client).to receive(:fetch).and_return(raw_csv)
      allow(parser).to receive(:parse).with(raw_csv).and_return(shops)

      expect(repository.all).to equal(shops)
    end

    it "propagates CsvClient::RemoteDataSourceError raised by the client" do
      allow(client).to receive(:fetch).and_raise(CsvClient::RemoteDataSourceError, "boom")

      expect { repository.all }.to raise_error(CsvClient::RemoteDataSourceError, "boom")
    end

    it "propagates CsvParser::ParseError raised by the parser" do
      allow(client).to receive(:fetch).and_return("garbage")
      allow(parser).to receive(:parse).and_raise(CsvParser::ParseError, "bad csv")

      expect { repository.all }.to raise_error(CsvParser::ParseError, "bad csv")
    end
  end

  describe "default collaborators" do
    it "defaults to a CsvClient instance and the CsvParser module" do
      repository = described_class.new

      expect(repository.send(:client)).to be_a(CsvClient)
      expect(repository.send(:parser)).to eq(CsvParser)
    end
  end
end
