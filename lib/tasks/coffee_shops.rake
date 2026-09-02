namespace :coffee_shops do
  desc "Import coffee shops from the remote CSV feed into the database, skipping shops that already exist (matched by name + coordinates)"
  task import: :environment do
    results = CoffeeShopImporter.new.call

    results.each do |result|
      shop = result[:coffee_shop]
      verdict = result[:imported] ? "imported" : "duplicate, skipped"
      puts "#{shop.name} (#{shop.coordinate_x}, #{shop.coordinate_y}): #{verdict}"
    end

    puts "Imported #{results.count { |result| result[:imported] }} coffee shop(s)."
  rescue CsvClient::RemoteDataSourceError, CsvParser::ParseError => e
    warn "Coffee shop import failed: #{e.message}"
    exit 1
  end
end
