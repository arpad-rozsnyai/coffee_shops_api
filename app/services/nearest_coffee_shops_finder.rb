class NearestCoffeeShopsFinder
  MAX_RESULTS = 3

  def initialize(repository: CoffeeShopRepository.new)
    @repository = repository
  end

  def call(x:, y:)
    repository.all
      .map { |shop| { coffee_shop: shop, distance: shop.distance_to(x, y) } }
      # Break exact distance ties by name so ordering is deterministic regardless of
      # the repository's row order (Array#sort_by is not guaranteed stable).
      .sort_by { |result| [ result[:distance], result[:coffee_shop].name ] }
      .first(MAX_RESULTS)
  end

  private

  attr_reader :repository
end
