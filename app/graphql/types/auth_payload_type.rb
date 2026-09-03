module Types
  class AuthPayloadType < Types::BaseObject
    field :access_token, String, null: false,
      description: "Short-lived token sent as \"Authorization: Bearer <token>\" on every authenticated request"
    field :access_token_expires_at, GraphQL::Types::ISO8601DateTime, null: false
    field :refresh_token, String, null: false,
      description: "Long-lived token accepted only by the refreshToken mutation to obtain a new access token"
    field :refresh_token_expires_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
