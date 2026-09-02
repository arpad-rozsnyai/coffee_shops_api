module Types
  class CoffeeShopType < Types::BaseObject
    description "A coffee shop persisted in the coffee_shops table"

    field :id, GraphQL::Types::ID, null: false
    field :name, String, null: false
    field :x, Float, null: false
    field :y, Float, null: false
    field :address, String, null: true
    field :open_until, String, null: true
  end
end
