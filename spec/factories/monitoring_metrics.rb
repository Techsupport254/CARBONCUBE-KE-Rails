FactoryBot.define do
  factory :monitoring_metric do
    name { "MyString" }
    value { "9.99" }
    timestamp { "2026-04-22 13:40:26" }
    tags { "" }
  end
end
