module Types
  class NearestCoffeeShopType < Types::BaseObject
    description "A coffee shop paired with its distance from a searched coordinate"

    field :coffee_shop, Types::CoffeeShopType, null: false
    field :distance, Float, null: false
    field :highlighted, Boolean, null: false,
      description: "True for the top results of a nearestCoffeeShops search; false otherwise"

    def coffee_shop
      object[:coffee_shop]
    end

    def distance
      object[:distance].round(4)
    end

    def highlighted
      object[:highlighted]
    end
  end
end
