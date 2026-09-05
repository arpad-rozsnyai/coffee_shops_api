module CoffeeShops
  # Default CSV URL for the challenge data source.
  # Override at runtime with the COFFEE_SHOPS_CSV_URL environment variable.
  DEFAULT_CSV_URL = "https://raw.githubusercontent.com/agilefreaks/test_oop/master/coffee_shops.csv".freeze

  # Shared fallback for any GraphQL `limit` argument left unspecified (omitted, null, zero, or
  # negative) - a single source of truth so every query result cap changes in one place.
  DEFAULT_LIMIT = 5

  # coffeeShops' own fallback, not DEFAULT_LIMIT - it's the guarded index/listing field (browse
  # everything, find an id to update/delete), where a small search-sized default isn't useful, unlike
  # nearestCoffeeShops (still on DEFAULT_LIMIT), which is an actual "top N nearest results" search.
  # Still bounded, not unlimited - a client can't trigger a genuinely unbounded query against the table.
  DEFAULT_INDEX_LIMIT = 500

  def self.csv_url
    ENV.fetch("COFFEE_SHOPS_CSV_URL", DEFAULT_CSV_URL)
  end
end
