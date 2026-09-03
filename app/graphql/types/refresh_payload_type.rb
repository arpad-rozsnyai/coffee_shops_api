module Types
  class RefreshPayloadType < Types::BaseObject
    field :access_token, String, null: false,
      description: "New short-lived token sent as \"Authorization: Bearer <token>\" on every authenticated request"
    field :access_token_expires_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
