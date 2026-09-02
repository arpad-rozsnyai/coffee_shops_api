class CoffeeShop
  attr_reader :name, :x, :y

  def initialize(name:, x:, y:)
    @name = name
    @x = x
    @y = y
  end

  def distance_to(x, y)
    Math.hypot(self.x - x, self.y - y)
  end
end
