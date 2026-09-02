class CoordinateValidator
  def self.call(x:, y:)
    new(x: x, y: y).call
  end

  def initialize(x:, y:)
    @raw_x = x
    @raw_y = y
  end

  def call
    parsed_x = parse(raw_x)
    parsed_y = parse(raw_y)

    errors = []
    errors << error_for(:x, raw_x) if parsed_x.nil?
    errors << error_for(:y, raw_y) if parsed_y.nil?

    { x: parsed_x, y: parsed_y, errors: errors }
  end

  private

  attr_reader :raw_x, :raw_y

  def parse(value)
    return nil if blank?(value)

    Float(value.to_s.strip)
  rescue ArgumentError
    nil
  end

  def error_for(attribute, raw_value)
    detail = blank?(raw_value) ? "can't be blank" : "is not a valid number"
    { attribute: attribute, detail: detail }
  end

  def blank?(value)
    value.nil? || value.to_s.strip.empty?
  end
end
