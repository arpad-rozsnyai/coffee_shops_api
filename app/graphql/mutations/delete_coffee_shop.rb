module Mutations
  class DeleteCoffeeShop < BaseMutation
    description "Deletes an existing coffee shop. Requires a valid access token"

    argument :id, GraphQL::Types::ID, required: true

    field :coffee_shop, Types::CoffeeShopType, null: true
    field :errors, [ String ], null: false

    def resolve(id:)
      authenticate!
      coffee_shop = find_coffee_shop(id)
      return { coffee_shop: nil, errors: [ NOT_FOUND_ERROR ] } unless coffee_shop

      coffee_shop.destroy
      { coffee_shop: coffee_shop, errors: [] }
    end
  end
end
