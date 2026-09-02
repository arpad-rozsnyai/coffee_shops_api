FactoryBot.define do
  factory :coffee_shop do
    sequence(:name) { |n| "Coffee Shop #{n}" }
    coordinate_x { 1.0 }
    coordinate_y { 2.0 }
    address { "123 Main St" }
    open_until { "9pm" }
  end
end
