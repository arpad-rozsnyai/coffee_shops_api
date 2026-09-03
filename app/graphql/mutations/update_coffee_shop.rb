module Mutations
  class UpdateCoffeeShop < BaseMutation
    description "Updates an existing coffee shop's attributes"

    argument :id, GraphQL::Types::ID, required: true
    argument :name, String, required: false
    argument :x, Float, required: false
    argument :y, Float, required: false
    argument :address, String, required: false
    argument :open_until, String, required: false

    field :coffee_shop, Types::CoffeeShopType, null: true
    field :errors, [ String ], null: false

    def resolve(id:, **attrs)
      coffee_shop = find_coffee_shop(id)
      return { coffee_shop: nil, errors: [ NOT_FOUND_ERROR ] } unless coffee_shop

      if coffee_shop.update(**attrs)
        { coffee_shop: coffee_shop, errors: [] }
      else
        { coffee_shop: nil, errors: coffee_shop.errors.full_messages }
      end
    end
  end
end
