module CoffeeShops
  # Default CSV URL for the challenge data source.
  # Override at runtime with the COFFEE_SHOPS_CSV_URL environment variable.
  DEFAULT_CSV_URL = "https://raw.githubusercontent.com/agilefreaks/test_oop/master/coffee_shops.csv".freeze

  def self.csv_url
    ENV.fetch("COFFEE_SHOPS_CSV_URL", DEFAULT_CSV_URL)
  end
end
