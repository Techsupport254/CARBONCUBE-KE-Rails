FactoryBot.define do
  factory :review_request do
    seller { nil }
    reason { "MyText" }
    status { "MyString" }
    requested_at { "2025-11-09 22:35:04" }
    reviewed_at { "2025-11-09 22:35:04" }
    reviewed_by { nil }
    review_notes { "MyText" }
  end
end
