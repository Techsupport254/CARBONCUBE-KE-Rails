FactoryBot.define do
  factory :comment_vote do
    comment { nil }
    author { nil }
    value { 1 }
  end
end
