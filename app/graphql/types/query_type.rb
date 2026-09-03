module Types
  class QueryType < Types::BaseObject
    HIGHLIGHTED_RESULTS_COUNT = 3

    field :coffee_shops, [ Types::CoffeeShopType ], null: false do
      description "Persisted coffee shops, optionally filtered by name and capped by limit " \
        "(default #{CoffeeShops::DEFAULT_INDEX_LIMIT}). Requires a valid access token"
      argument :name, String, required: false,
        description: "Case-insensitive partial match against the coffee shop name"
      argument :limit, Integer, required: false,
        description: "Maximum number of results to return. Defaults to " \
          "#{CoffeeShops::DEFAULT_INDEX_LIMIT} when omitted, null, or not a positive number"
    end

    field :coffee_shop, Types::CoffeeShopType, null: true do
      description "A single persisted coffee shop by id. Requires a valid access token"
      argument :id, GraphQL::Types::ID, required: true
    end

    field :nearest_coffee_shops, [ Types::NearestCoffeeShopType ], null: false do
      description "The nearest persisted coffee shops to a coordinate, optionally filtered by name, " \
        "ordered nearest to farthest and capped by limit (default #{CoffeeShops::DEFAULT_LIMIT}). " \
        "The first #{HIGHLIGHTED_RESULTS_COUNT} results are flagged as highlighted"
      argument :x, Float, required: true
      argument :y, Float, required: true
      argument :name, String, required: false,
        description: "Case-insensitive partial match against the coffee shop name"
      argument :limit, Integer, required: false,
        description: "Maximum number of results to return. Defaults to " \
          "#{CoffeeShops::DEFAULT_LIMIT} when omitted, null, or not a positive number"
    end

    def coffee_shops(name: nil, limit: nil)
      authenticate!
      scope = name.present? ? CoffeeShop.name_contains(name) : CoffeeShop
      scope.limit(positive_or_default(limit, default: CoffeeShops::DEFAULT_INDEX_LIMIT)).order(:id)
    end

    def coffee_shop(id:)
      authenticate!
      CoffeeShop.find_by(id: id)
    end

    # Deliberately the one search field left public - see Authentication in CLAUDE.md for why
    # coffeeShops/coffeeShop are guarded but this one isn't.
    def nearest_coffee_shops(x:, y:, name: nil, limit: nil)
      results = NearestCoffeeShopsFinder.new(repository: CoffeeShop)
        .call(x: x, y: y, name: name, limit: positive_or_default(limit))

      results.each_with_index.map do |result, index|
        result.merge(highlighted: index < HIGHLIGHTED_RESULTS_COUNT)
      end
    end

    private

    def positive_or_default(limit, default: CoffeeShops::DEFAULT_LIMIT)
      limit.is_a?(Integer) && limit.positive? ? limit : default
    end

    # Mirrors Mutations::BaseMutation#authenticate! - not shared via a common module, the two class
    # hierarchies (Types::BaseObject vs GraphQL::Schema::Mutation) don't share an ancestor, and it's
    # one line; not worth a module for that.
    def authenticate!
      raise GraphQL::ExecutionError, "Unauthorized" unless context[:current_user].present?
    end
  end
end
