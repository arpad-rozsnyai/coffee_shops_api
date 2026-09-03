module Mutations
  class BaseMutation < GraphQL::Schema::Mutation
    NOT_FOUND_ERROR = "Coffee shop not found".freeze

    private

    def find_coffee_shop(id)
      CoffeeShop.find_by(id: id)
    end

    def authenticate!
      raise GraphQL::ExecutionError, "Unauthorized" unless context[:current_user].present?
    end
  end
end
