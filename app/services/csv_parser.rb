require "csv"

# The remote data source has no header row — each row is positional:
# column 0 = Name, column 1 = X, column 2 = Y (see README's Data Source section).
class CsvParser
  class ParseError < StandardError
  end

  NAME_COLUMN = 0
  X_COLUMN = 1
  Y_COLUMN = 2

  def self.parse(csv_string)
    new(csv_string).parse
  end

  def initialize(csv_string)
    @csv_string = csv_string
  end

  def parse
    build_shops(build_rows)
  end

  private

  attr_reader :csv_string

  def build_rows
    CSV.parse(csv_string, headers: false, skip_blanks: true)
  rescue CSV::MalformedCSVError => e
    raise ParseError, "Malformed CSV structure: #{e.message}"
  end

  def build_shops(rows)
    rows.each_with_object([]) do |row, shops|
      shop = build_shop(row)
      shops << shop if shop
    end
  end

  def build_shop(row)
    name = row[NAME_COLUMN]&.strip
    return nil if name.nil? || name.empty?

    x = strict_float(row[X_COLUMN])
    y = strict_float(row[Y_COLUMN])
    return nil if x.nil? || y.nil?

    CoffeeShop.new(name: name, x: x, y: y)
  end

  def strict_float(value)
    return nil if value.nil?

    Float(value.strip)
  rescue ArgumentError
    nil
  end
end
