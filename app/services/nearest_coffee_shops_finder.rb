class NearestCoffeeShopsFinder
  def initialize(repository:)
    @repository = repository
  end

  def call(x:, y:, name: nil, limit: nil)
    limit ||= CoffeeShops::DEFAULT_LIMIT
    scope = name.present? ? repository.name_contains(name) : repository

    scope
      .select(repository.sanitize_sql_array([
        "coffee_shops.*, SQRT(POWER(coordinate_x - ?, 2) + POWER(coordinate_y - ?, 2)) AS distance", x, y
      ]))
      .order(Arel.sql("distance ASC, name ASC"))
      .limit(limit)
      .map { |shop| { coffee_shop: shop, distance: shop.distance } }
  end

  private

  attr_reader :repository
end
