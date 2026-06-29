FactoryBot.define do
  factory :call_record do
    customer { nil }
    sales_user { nil }
    status { 1 }
    call_type { 1 }
    duration_seconds { 1 }
    started_at { "2026-06-23 14:36:17" }
    ended_at { "2026-06-23 14:36:17" }
    csat_score { 1 }
  end
end
