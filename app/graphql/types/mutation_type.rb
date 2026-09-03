module Types
  class MutationType < Types::BaseObject
    field :create_coffee_shop, mutation: Mutations::CreateCoffeeShop
    field :update_coffee_shop, mutation: Mutations::UpdateCoffeeShop
    field :delete_coffee_shop, mutation: Mutations::DeleteCoffeeShop
  end
end
