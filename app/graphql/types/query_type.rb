module Types
  class QueryType < Types::BaseObject
    MAX_COFFEE_SHOPS = 5

    field :coffee_shops, [ Types::CoffeeShopType ], null: false do
      description "All persisted coffee shops (capped at #{MAX_COFFEE_SHOPS}), optionally filtered by name"
      argument :name, String, required: false,
        description: "Case-insensitive partial match against the coffee shop name"
    end

    field :coffee_shop, Types::CoffeeShopType, null: true do
      description "A single persisted coffee shop by id"
      argument :id, GraphQL::Types::ID, required: true
    end

    field :nearest_coffee_shops, [ Types::NearestCoffeeShopType ], null: false do
      description "The nearest persisted coffee shops to a coordinate, ordered nearest to farthest"
      argument :x, Float, required: true
      argument :y, Float, required: true
    end

    def coffee_shops(name: nil)
      scope = name.present? ? CoffeeShop.name_contains(name) : CoffeeShop
      scope.limit(MAX_COFFEE_SHOPS)
    end

    def coffee_shop(id:)
      CoffeeShop.find_by(id: id)
    end

    def nearest_coffee_shops(x:, y:)
      NearestCoffeeShopsFinder.new(repository: CoffeeShop).call(x: x, y: y)
    end
  end
end
