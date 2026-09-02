class CoffeeShopImporter
  def initialize(client: CsvClient.new, parser: CsvParser)
    @client = client
    @parser = parser
  end

  def call
    shops = parser.parse(client.fetch)
    shops.map { |shop| import(shop) }
  end

  private

  attr_reader :client, :parser

  def import(shop)
    duplicate = CoffeeShop.exists?(name: shop.name, coordinate_x: shop.coordinate_x, coordinate_y: shop.coordinate_y)
    shop.save! unless duplicate

    { coffee_shop: shop, imported: !duplicate }
  end
end
