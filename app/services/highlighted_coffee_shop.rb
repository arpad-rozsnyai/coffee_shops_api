class HighlightedCoffeeShop < SimpleDelegator
  attr_reader :highlighted

  def initialize(coffee_shop, highlighted:)
    super(coffee_shop)
    @highlighted = highlighted
  end
end
