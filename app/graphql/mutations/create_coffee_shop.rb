module Mutations
  class CreateCoffeeShop < BaseMutation
    description "Creates a new coffee shop. Requires a valid access token"

    argument :name, String, required: true
    argument :x, Float, required: true
    argument :y, Float, required: true
    argument :address, String, required: true
    argument :open_until, String, required: true

    field :coffee_shop, Types::CoffeeShopType, null: true
    field :errors, [ String ], null: false

    def resolve(**attrs)
      authenticate!
      coffee_shop = CoffeeShop.new(**attrs)

      if coffee_shop.save
        { coffee_shop: coffee_shop, errors: [] }
      else
        { coffee_shop: nil, errors: coffee_shop.errors.full_messages }
      end
    end
  end
end
