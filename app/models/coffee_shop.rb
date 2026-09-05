class CoffeeShop < ApplicationRecord
  DUPLICATE_ERROR_MESSAGE = "A coffee shop with this name and location already exists".freeze

  alias_attribute :x, :coordinate_x
  alias_attribute :y, :coordinate_y

  attr_readonly :slug

  before_validation :generate_slug, on: :create

  validates :name, presence: true
  validates :coordinate_x, :coordinate_y, presence: true, numericality: true
  validates :slug, presence: true
  validate :slug_must_be_unique, on: :create

  scope :name_contains, ->(fragment) { where(arel_table[:name].matches("%#{sanitize_sql_like(fragment)}%")) }

  # Ransack's mass-assignment safelist - used only by the ActiveAdmin filters (app/admin/coffee_shop.rb).
  def self.ransackable_attributes(_auth_object = nil)
    %w[id name]
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

  # slug is only ever generated on create and is immutable afterward (attr_readonly), so uniqueness
  # only needs checking at creation - no need to exclude self by id the way update-time uniqueness
  # checks normally would. Errors attach to :base, not :slug, with a message that doesn't leak the
  # internal "slug" concept - it's never accepted input and isn't exposed via GraphQL.
  def slug_must_be_unique
    errors.add(:base, DUPLICATE_ERROR_MESSAGE) if self.class.exists?(slug: slug)
  end
end
