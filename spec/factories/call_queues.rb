FactoryBot.define do
  factory :call_queue do
    seller { "" }
    queue_type { "MyString" }
    priority { 1 }
    metadata { "" }
    status { "MyString" }
    resolved_at { "2026-06-26 08:21:53" }
    resolved_by { "" }
  end
end
