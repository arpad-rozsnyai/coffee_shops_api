class CoffeeShop < ApplicationRecord
  alias_attribute :x, :coordinate_x
  alias_attribute :y, :coordinate_y

  attr_readonly :slug

  before_validation :generate_slug, on: :create

  validates :name, presence: true
  validates :coordinate_x, :coordinate_y, presence: true
  validates :slug, presence: true, uniqueness: true

  def distance_to(x, y)
    Math.hypot(self.x - x, self.y - y)
  end

  private

  # Coordinate signs are encoded explicitly (see #signed_component) because plain #parameterize strips
  # "-", which would otherwise collide a point with its sign-flipped counterpart.
  def generate_slug
    self.slug = [ name, signed_component(coordinate_x), signed_component(coordinate_y) ].join("-").parameterize
  end

  def signed_component(value)
    value&.negative? ? "neg#{value.abs}" : value.to_s
  end
end
