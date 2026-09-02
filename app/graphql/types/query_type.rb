module Types
  class QueryType < Types::BaseObject
    DEFAULT_COFFEE_SHOPS_LIMIT = 5
    HIGHLIGHTED_RESULTS_COUNT = 3

    field :coffee_shops, [ Types::CoffeeShopType ], null: false do
      description "Persisted coffee shops, optionally filtered by name and capped by limit " \
        "(default #{DEFAULT_COFFEE_SHOPS_LIMIT}). The first #{HIGHLIGHTED_RESULTS_COUNT} results " \
        "are flagged as highlighted"
      argument :name, String, required: false,
        description: "Case-insensitive partial match against the coffee shop name"
      argument :limit, Integer, required: false,
        description: "Maximum number of results to return. Defaults to " \
          "#{DEFAULT_COFFEE_SHOPS_LIMIT} when omitted, null, or not a positive number"
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

    def coffee_shops(name: nil, limit: nil)
      scope = name.present? ? CoffeeShop.name_contains(name) : CoffeeShop
      scope.limit(coffee_shops_limit(limit)).order(:id).each_with_index.map do |coffee_shop, index|
        coffee_shop.tap { |shop| shop.highlighted = index < HIGHLIGHTED_RESULTS_COUNT }
      end
    end

    def coffee_shop(id:)
      CoffeeShop.find_by(id: id)
    end

    def nearest_coffee_shops(x:, y:)
      NearestCoffeeShopsFinder.new(repository: CoffeeShop).call(x: x, y: y)
    end

    private

    def coffee_shops_limit(limit)
      limit.is_a?(Integer) && limit.positive? ? limit : DEFAULT_COFFEE_SHOPS_LIMIT
    end
  end
end
