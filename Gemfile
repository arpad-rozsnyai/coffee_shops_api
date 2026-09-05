source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Flexible authentication solution for Rails [https://github.com/heartcombo/devise]
gem "devise", "~> 5.0"

# Encode/decode JSON Web Tokens for the GraphQL access/refresh token flow
gem "jwt", "~> 3.2"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Ruby 3.4+ dropped csv from the default gems bundled with the interpreter
# (CsvParser relies on stdlib CSV), so it must be declared explicitly here.
gem "csv"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.6"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
# gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  gem "rspec-rails"

  gem "factory_bot_rails"
end

group :test do
  gem "webmock"
end

gem "graphql", "~> 2.6"

# Asset pipeline — needed in every environment (not just development) because ActiveAdmin's
# admin UI (see below) is a real, production-served interface, unlike GraphiQL below which is
# development-only. Order matters relative to graphiql-rails — see CLAUDE.md's GraphiQL section.
gem "sprockets-rails"

# Admin UI for managing coffee shops [https://github.com/activeadmin/activeadmin]
gem "activeadmin", "~> 3.5"
gem "sassc-rails"

group :development do
  gem "graphiql-rails"
end
