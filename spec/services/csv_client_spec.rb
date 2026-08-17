require "rails_helper"

RSpec.describe CsvClient do
  let(:url) { "https://example.com/coffee_shops.csv" }
  let(:client) { described_class.new(url: url) }

  describe "#fetch" do
    context "when the request succeeds" do
      it "returns the raw response body" do
        stub_request(:get, url).to_return(status: 200, body: "Name,X,Y\nStarbucks,47.6,-122.4\n")

        expect(client.fetch).to eq("Name,X,Y\nStarbucks,47.6,-122.4\n")
      end
    end

    context "when the request times out" do
      it "raises a CsvClient::RemoteDataSourceError" do
        stub_request(:get, url).to_timeout

        expect { client.fetch }.to raise_error(CsvClient::RemoteDataSourceError, /timed out/i)
      end
    end

    context "when the connection fails" do
      it "raises a CsvClient::RemoteDataSourceError" do
        stub_request(:get, url).to_raise(SocketError)

        expect { client.fetch }.to raise_error(CsvClient::RemoteDataSourceError, /failed to reach/i)
      end
    end

    context "when the response is a non-2xx status" do
      it "raises a CsvClient::RemoteDataSourceError" do
        stub_request(:get, url).to_return(status: 404, body: "Not Found")

        expect { client.fetch }.to raise_error(CsvClient::RemoteDataSourceError, /HTTP 404/)
      end
    end

    context "when the configured URL is invalid" do
      it "raises a CsvClient::RemoteDataSourceError without making a request" do
        invalid_client = described_class.new(url: "not a url")

        expect { invalid_client.fetch }.to raise_error(CsvClient::RemoteDataSourceError, /invalid coffee shop csv url/i)
      end
    end
  end
end
