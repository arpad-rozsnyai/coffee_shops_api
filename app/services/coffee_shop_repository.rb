class CoffeeShopRepository
  def initialize(client: CsvClient.new, parser: CsvParser)
    @client = client
    @parser = parser
  end

  def all
    parser.parse(client.fetch)
  end

  private

  attr_reader :client, :parser
end
