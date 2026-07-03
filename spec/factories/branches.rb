FactoryBot.define do
  factory :branch do
    seller { nil }
    name { "MyString" }
    description { "MyText" }
    location { "MyString" }
    latitude { 1.5 }
    longitude { 1.5 }
    phone { "MyString" }
    is_main_branch { false }
  end
end
