FactoryBot.define do
  factory :notification do
    user { nil }
    title { "MyString" }
    body { "MyText" }
    data { "" }
    read_at { "2026-02-12 15:24:06" }
  end
end
