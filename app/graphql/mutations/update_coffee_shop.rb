module Mutations
  class UpdateCoffeeShop < BaseMutation
    description "Updates an existing coffee shop's attributes. Requires a valid access token"

    # address/openUntil are optional on update (unlike create) specifically so a caller can update
    # just the name/coordinates of a CSV-imported shop that has neither on record yet - see
    # #without_blanks for why a blank value for either is then dropped rather than passed through.
    PRESERVE_IF_BLANK = %i[address open_until].freeze

    argument :id, GraphQL::Types::ID, required: true
    argument :name, String, required: false
    argument :x, Float, required: false
    argument :y, Float, required: false
    argument :address, String, required: false
    argument :open_until, String, required: false

    field :coffee_shop, Types::CoffeeShopType, null: true
    field :errors, [ String ], null: false

    def resolve(id:, **attrs)
      authenticate!
      coffee_shop = find_coffee_shop(id)
      raise GraphQL::ExecutionError, NOT_FOUND_ERROR unless coffee_shop

      attrs = without_blanks(attrs)
      # update(**{}) raises ArgumentError (it requires at least one argument) - nothing left to
      # change (e.g. only a blank address/openUntil was given) is a no-op, not an update call.
      if attrs.empty? || coffee_shop.update(**attrs)
        { coffee_shop: coffee_shop, errors: [] }
      else
        raise GraphQL::ExecutionError, coffee_shop.errors.full_messages.join("; ")
      end
    end

    private

    # A blank (nil or "") address/openUntil leaves the existing value untouched instead of
    # overwriting it - the model doesn't validate their presence (CoffeeShopImporter creates shops
    # with neither), so update wouldn't otherwise reject a value that blanks them out.
    def without_blanks(attrs)
      attrs.reject { |key, value| PRESERVE_IF_BLANK.include?(key) && value.blank? }
    end
  end
end
