class CoffeeShop < ApplicationRecord
  alias_attribute :x, :coordinate_x
  alias_attribute :y, :coordinate_y

  validates :name, presence: true
  validates :coordinate_x, :coordinate_y, presence: true
  validates :name, uniqueness: { scope: [ :coordinate_x, :coordinate_y ] }

  def distance_to(x, y)
    Math.hypot(self.x - x, self.y - y)
  end
end
