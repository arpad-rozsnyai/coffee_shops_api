# Works around a graphiql-rails gap — see CLAUDE.md's GraphiQL section.
Rails.application.config.assets.precompile += %w[graphiql/rails/application.js] if Rails.env.development?
