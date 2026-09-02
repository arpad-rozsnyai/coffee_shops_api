class NearestCoffeeShopsFinder
  MAX_RESULTS = 3

  def initialize(repository:)
    @repository = repository
  end

  def call(x:, y:)
    repository.all
      .map { |shop| { coffee_shop: shop, distance: shop.distance_to(x, y) } }
      # Break exact distance ties by name so ordering is deterministic regardless of
      # the repository's row order. min_by(n) does a partial selection instead of
      # sorting the full array, since we only ever need the top MAX_RESULTS.
      .min_by(MAX_RESULTS) { |result| [ result[:distance], result[:coffee_shop].name ] }
  end

  private

  attr_reader :repository
end
