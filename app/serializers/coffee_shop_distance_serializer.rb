require "digest"

class CoffeeShopDistanceSerializer
  def initialize(results)
    @results = results
  end

  def as_json(*)
    { data: results.map { |result| serialize(result) } }
  end

  private

  attr_reader :results

  def serialize(result)
    shop = result[:coffee_shop]

    {
      id: id_for(shop),
      type: "coffee_shops",
      attributes: {
        name: shop.name,
        x: shop.x,
        y: shop.y,
        distance: result[:distance].round(4)
      }
    }
  end

  def id_for(shop)
    Digest::SHA1.hexdigest("#{shop.name}:#{shop.x}:#{shop.y}")
  end
end
