module Types
  class QueryType < Types::BaseObject
    HIGHLIGHTED_RESULTS_COUNT = 3

    field :coffee_shops, [ Types::CoffeeShopType ], null: false do
      description "Persisted coffee shops, optionally filtered by name and capped by limit " \
        "(default #{CoffeeShops::DEFAULT_LIMIT}). The first #{HIGHLIGHTED_RESULTS_COUNT} results " \
        "are flagged as highlighted"
      argument :name, String, required: false,
        description: "Case-insensitive partial match against the coffee shop name"
      argument :limit, Integer, required: false,
        description: "Maximum number of results to return. Defaults to " \
          "#{CoffeeShops::DEFAULT_LIMIT} when omitted, null, or not a positive number"
    end

    field :coffee_shop, Types::CoffeeShopType, null: true do
      description "A single persisted coffee shop by id"
      argument :id, GraphQL::Types::ID, required: true
    end

    field :nearest_coffee_shops, [ Types::NearestCoffeeShopType ], null: false do
      description "The nearest persisted coffee shops to a coordinate, optionally filtered by name, " \
        "ordered nearest to farthest and capped by limit (default #{CoffeeShops::DEFAULT_LIMIT})"
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
      scope.limit(positive_or_default(limit)).order(:id).each_with_index.map do |coffee_shop, index|
        coffee_shop.tap { |shop| shop.highlighted = index < HIGHLIGHTED_RESULTS_COUNT }
      end
    end

    def coffee_shop(id:)
      authenticate!
      CoffeeShop.find_by(id: id)
    end

    def nearest_coffee_shops(x:, y:, name: nil, limit: nil)
      authenticate!
      NearestCoffeeShopsFinder.new(repository: CoffeeShop)
        .call(x: x, y: y, name: name, limit: positive_or_default(limit))
    end

    private

    def positive_or_default(limit)
      limit.is_a?(Integer) && limit.positive? ? limit : CoffeeShops::DEFAULT_LIMIT
    end

    # Checked per-field, not via a type-level `self.authorized?` override - that hook also gates
    # __schema/__type introspection (they're resolved as fields on this same root type), which would
    # break GraphiQL's schema explorer for everyone, token or not (confirmed by calling
    # CoffeeShopsApiSchema.execute directly with "{ __schema { queryType { name } } }").
    def authenticate!
      raise GraphQL::ExecutionError, "Unauthorized" unless context[:current_user].present?
    end
  end
end
