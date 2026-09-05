module Mutations
  class CreateCoffeeShop < BaseMutation
    description "Creates a new coffee shop. Requires a valid access token"

    # required: true on address/openUntil only guarantees they're present (non-null) - GraphQL's own
    # argument coercion doesn't reject an empty/whitespace-only string, so that's checked separately
    # in #resolve. It can't be a model validation instead: CoffeeShop deliberately allows a nil
    # open_until/address (CoffeeShopImporter creates shops with neither), and this needs to reject
    # blank without also rejecting nil.
    MANDATORY_STRING_ARGUMENTS = %i[address open_until].freeze

    argument :name, String, required: true
    argument :x, Float, required: true
    argument :y, Float, required: true
    argument :address, String, required: true
    argument :open_until, String, required: true

    field :coffee_shop, Types::CoffeeShopType, null: true
    field :errors, [ String ], null: false

    def resolve(**attrs)
      authenticate!
      errors = blank_argument_errors(attrs)
      raise GraphQL::ExecutionError, errors.join("; ") if errors.any?

      coffee_shop = CoffeeShop.new(**attrs)

      if coffee_shop.save
        { coffee_shop: coffee_shop, errors: [] }
      else
        raise GraphQL::ExecutionError, coffee_shop.errors.full_messages.join("; ")
      end
    end

    private

    def blank_argument_errors(attrs)
      MANDATORY_STRING_ARGUMENTS
        .select { |key| attrs[key].blank? }
        .map { |key| "#{key.to_s.humanize} can't be blank" }
    end
  end
end
