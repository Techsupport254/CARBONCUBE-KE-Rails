FactoryBot.define do
  factory :email_communication_log do
    seller { nil }
    email_type { "MyString" }
    message_id { "MyString" }
    sent_successfully { false }
    error_message { "MyText" }
    sent_at { "2026-05-13 15:03:07" }
  end
end
