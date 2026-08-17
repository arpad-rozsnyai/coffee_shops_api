Rswag::Api.configure do |c|
  # Must match config.openapi_root in spec/swagger_helper.rb, so rswag-specs
  # writes to the same place this middleware serves from.
  c.openapi_root = Rails.root.to_s + "/swagger"
end
