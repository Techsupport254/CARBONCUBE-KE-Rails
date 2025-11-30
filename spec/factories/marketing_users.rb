FactoryBot.define do
  factory :marketing_user do
    fullname { "MyString" }
    email { "MyString" }
    password_digest { "MyString" }
    provider { "MyString" }
    uid { "MyString" }
    oauth_token { "MyString" }
    oauth_refresh_token { "MyString" }
    oauth_expires_at { "MyString" }
  end
end
