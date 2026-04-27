FactoryBot.define do
  factory :monitoring_error do
    message { "MyString" }
    stack_trace { "MyText" }
    level { "MyString" }
    context { "" }
    resolved_at { "2026-04-22 13:40:26" }
  end
end
