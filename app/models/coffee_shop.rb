class CoffeeShop < ApplicationRecord
  # Aliases keep the existing CSV pipeline (CsvParser, NearestCoffeeShopsFinder, ...) working
  # unchanged against the same x/y interface it always used, now backed by real columns.
  alias_attribute :x, :coordinate_x
  alias_attribute :y, :coordinate_y

  validates :name, presence: true
  validates :coordinate_x, :coordinate_y, presence: true

  def distance_to(x, y)
    Math.hypot(self.x - x, self.y - y)
  end
end
