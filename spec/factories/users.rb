FactoryBot.define do
  factory :user do
    name { "Jane Doe" }
    sequence(:email) { |n| "jane#{n}@example.com" }
    password { "correct-password" }
  end
end
