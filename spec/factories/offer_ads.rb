FactoryBot.define do
  factory :offer_ad do
    offer { nil }
    ad { nil }
    discount_percentage { "9.99" }
    original_price { "9.99" }
    discounted_price { "9.99" }
    is_active { false }
  end
end
