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

    context "encoding" do
      it "tags the body as UTF-8 rather than the ASCII-8BIT Net::HTTP defaults to" do
        stub_request(:get, url).to_return(status: 200, body: "Name,X,Y\nStarbucks,47.6,-122.4\n",
                                           headers: { "Content-Type" => "text/plain; charset=utf-8" })

        expect(client.fetch.encoding).to eq(Encoding::UTF_8)
      end

      it "transcodes a body declared in a non-UTF-8 charset to UTF-8" do
        body = "Caf\xE9,47.6,-122.4\n".dup.force_encoding(Encoding::ISO_8859_1)
        stub_request(:get, url).to_return(status: 200, body: body,
                                           headers: { "Content-Type" => "text/plain; charset=iso-8859-1" })

        result = client.fetch

        expect(result.encoding).to eq(Encoding::UTF_8)
        expect(result).to eq("Café,47.6,-122.4\n")
      end

      it "defaults to UTF-8 when the response has no charset at all" do
        stub_request(:get, url).to_return(status: 200, body: "Name,X,Y\nStarbucks,47.6,-122.4\n")

        expect(client.fetch.encoding).to eq(Encoding::UTF_8)
      end

      it "raises a CsvClient::RemoteDataSourceError when the body is not valid text in its declared charset" do
        invalid_utf8 = "Name,X,Y\n\xFF\xFE,47.6,-122.4\n".dup.force_encoding(Encoding::UTF_8)
        stub_request(:get, url).to_return(status: 200, body: invalid_utf8,
                                           headers: { "Content-Type" => "text/plain; charset=utf-8" })

        expect { client.fetch }.to raise_error(CsvClient::RemoteDataSourceError, /not valid/i)
      end

      it "raises a CsvClient::RemoteDataSourceError when the declared charset is unknown" do
        stub_request(:get, url).to_return(status: 200, body: "Name,X,Y\nStarbucks,47.6,-122.4\n",
                                           headers: { "Content-Type" => "text/plain; charset=not-a-real-charset" })

        expect { client.fetch }.to raise_error(CsvClient::RemoteDataSourceError, /unknown charset/i)
      end
    end
  end
end
