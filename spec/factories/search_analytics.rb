FactoryBot.define do
  factory :search_analytic do
    date { "2026-01-19" }
    total_searches_today { 1 }
    unique_search_terms_today { 1 }
    total_search_records { 1 }
    popular_searches_all_time { "MyText" }
    popular_searches_daily { "MyText" }
    popular_searches_weekly { "MyText" }
    popular_searches_monthly { "MyText" }
    raw_analytics_data { "" }
  end
end
