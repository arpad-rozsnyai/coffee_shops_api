# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Must match Rswag::Api.configure's openapi_root in config/initializers/rswag_api.rb.
  config.openapi_root = Rails.root.join('swagger').to_s

  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Coffee Shops API',
        version: 'v1',
        description: "Given a user's X/Y coordinates, returns the three nearest coffee shops " \
                      'from a remote CSV data source, ordered nearest to farthest.'
      },
      paths: {}
      # No `servers` key: with none declared, Swagger UI both hides the
      # (otherwise pointless, single-option) Servers dropdown and still
      # defaults "Try it out" requests to the page's own origin — the same
      # relative-URL behavior as an explicit `servers: [{ url: '/' }]`, without
      # rendering a selector for a choice that doesn't exist.
    }
  }

  config.openapi_format = :yaml
end
