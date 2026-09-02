require "net/http"

class CsvClient
  class RemoteDataSourceError < StandardError
  end

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  def initialize(url: CoffeeShops.csv_url, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT)
    @url = url
    @open_timeout = open_timeout
    @read_timeout = read_timeout
  end

  def fetch
    extract_body(perform_request(build_uri))
  rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
    raise RemoteDataSourceError, "Timed out fetching coffee shop CSV: #{e.message}"
  rescue SocketError, Errno::ECONNREFUSED, EOFError => e
    raise RemoteDataSourceError, "Failed to reach coffee shop CSV source: #{e.message}"
  end

  private

  attr_reader :url, :open_timeout, :read_timeout

  def build_uri
    uri = URI.parse(url)
    raise RemoteDataSourceError, "Invalid coffee shop CSV URL: #{url.inspect}" unless uri.is_a?(URI::HTTP) && uri.host

    uri
  rescue URI::InvalidURIError => e
    raise RemoteDataSourceError, "Invalid coffee shop CSV URL: #{e.message}"
  end

  def perform_request(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: open_timeout, read_timeout: read_timeout) do |http|
      http.get(uri)
    end
  end

  def extract_body(response)
    unless response.is_a?(Net::HTTPSuccess)
      raise RemoteDataSourceError, "Unexpected response fetching coffee shop CSV: HTTP #{response.code}"
    end

    normalize_encoding(response.body, response.type_params["charset"])
  end

  # Net::HTTP never tags the body with the charset the server declares in Content-Type — it always
  # comes back as ASCII-8BIT (confirmed against the real feed, which returns "charset=utf-8" in its
  # header yet an ASCII-8BIT-tagged body).
  def normalize_encoding(body, charset)
    encoding = Encoding.find(charset || Encoding::UTF_8.name)
    text = body.dup.force_encoding(encoding)
    raise RemoteDataSourceError, "Coffee shop CSV response was not valid #{encoding} text" unless text.valid_encoding?

    text.encode(Encoding::UTF_8)
  rescue ArgumentError
    raise RemoteDataSourceError, "Coffee shop CSV response declared an unknown charset: #{charset.inspect}"
  end
end
