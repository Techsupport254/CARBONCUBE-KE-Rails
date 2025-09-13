# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_13_090432) do
  create_schema "auth"
  create_schema "extensions"
  create_schema "graphql"
  create_schema "graphql_public"
  create_schema "pgbouncer"
  create_schema "realtime"
  create_schema "storage"
  create_schema "vault"

  # These are extensions that must be enabled in order to support this database
  enable_extension "extensions.pg_stat_statements"
  enable_extension "extensions.pgcrypto"
  enable_extension "extensions.uuid-ossp"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "abouts", force: :cascade do |t|
    t.text "description"
    t.text "mission"
    t.text "vision"
    t.jsonb "values", default: []
    t.text "why_choose_us"
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ad_searches", force: :cascade do |t|
    t.string "search_term", null: false
    t.bigint "buyer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["buyer_id"], name: "index_ad_searches_on_buyer_id"
  end

  create_table "admins", force: :cascade do |t|
    t.string "fullname"
    t.string "username"
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ads", force: :cascade do |t|
    t.bigint "seller_id", null: false
    t.bigint "category_id", null: false
    t.bigint "subcategory_id", null: false
    t.string "title"
    t.text "description"
    t.text "media"
    t.decimal "price", precision: 10, scale: 2
    t.string "brand"
    t.integer "condition", default: 0, null: false
    t.string "manufacturer"
    t.decimal "item_weight", precision: 10, scale: 2
    t.string "weight_unit", default: "Grams"
    t.decimal "item_length", precision: 10, scale: 2
    t.decimal "item_width", precision: 10, scale: 2
    t.decimal "item_height", precision: 10, scale: 2
    t.boolean "flagged", default: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.boolean "deleted", default: false
    t.integer "reviews_count", default: 0, null: false
    t.index ["category_id", "deleted", "flagged", "created_at"], name: "index_ads_on_category_deleted_flagged_created_at"
    t.index ["category_id", "deleted", "flagged"], name: "index_ads_on_category_deleted_flagged"
    t.index ["category_id"], name: "index_ads_on_category_id"
    t.index ["deleted", "flagged", "created_at"], name: "index_ads_on_deleted_flagged_created_at"
    t.index ["deleted", "flagged", "created_at"], name: "index_ads_on_deleted_flagged_created_at_perf"
    t.index ["deleted", "flagged", "seller_id", "created_at", "id"], name: "index_ads_best_sellers_perf"
    t.index ["deleted", "flagged", "seller_id", "created_at"], name: "index_ads_on_deleted_flagged_seller_created_at"
    t.index ["deleted", "flagged", "subcategory_id", "created_at"], name: "index_ads_on_deleted_flagged_subcategory_created_at"
    t.index ["description"], name: "index_ads_on_description", opclass: :gin_trgm_ops, using: :gin
    t.index ["reviews_count"], name: "index_ads_on_reviews_count"
    t.index ["seller_id", "deleted", "flagged"], name: "index_ads_on_seller_deleted_flagged"
    t.index ["seller_id", "deleted", "flagged"], name: "index_ads_on_seller_deleted_flagged_perf"
    t.index ["seller_id"], name: "index_ads_on_seller_id"
    t.index ["subcategory_id", "deleted", "flagged", "created_at"], name: "index_ads_on_subcategory_deleted_flagged_created_at"
    t.index ["subcategory_id", "deleted", "flagged"], name: "index_ads_on_subcategory_deleted_flagged"
    t.index ["subcategory_id"], name: "index_ads_on_subcategory_id"
    t.index ["title"], name: "index_ads_on_title", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "age_groups", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_age_groups_on_name", unique: true
  end

  create_table "analytics", force: :cascade do |t|
    t.string "type"
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source"
    t.string "referrer"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_campaign"
    t.text "user_agent"
    t.string "ip_address"
  end

  create_table "banners", force: :cascade do |t|
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "best_sellers_cache", force: :cascade do |t|
    t.string "cache_key", null: false
    t.jsonb "data", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cache_key"], name: "index_best_sellers_cache_on_cache_key", unique: true
    t.index ["expires_at"], name: "index_best_sellers_cache_on_expires_at"
  end

  create_table "buyers", id: :bigint, default: -> { "nextval('purchasers_id_seq'::regclass)" }, force: :cascade do |t|
    t.string "fullname", null: false
    t.string "username", null: false
    t.string "password_digest"
    t.string "email", null: false
    t.string "phone_number", limit: 10, null: false
    t.bigint "age_group_id", null: false
    t.string "zipcode"
    t.string "city", null: false
    t.string "gender", default: "Male", null: false
    t.string "location"
    t.string "profile_picture"
    t.boolean "blocked", default: false
    t.bigint "county_id"
    t.bigint "sub_county_id"
    t.bigint "income_id"
    t.bigint "employment_id"
    t.bigint "education_id"
    t.bigint "sector_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "deleted", default: false, null: false
    t.index "lower((email)::text)", name: "index_purchasers_on_lower_email", unique: true
    t.index ["age_group_id"], name: "index_buyers_on_age_group_id"
    t.index ["county_id"], name: "index_buyers_on_county_id"
    t.index ["education_id"], name: "index_buyers_on_education_id"
    t.index ["employment_id"], name: "index_buyers_on_employment_id"
    t.index ["income_id"], name: "index_buyers_on_income_id"
    t.index ["sector_id"], name: "index_buyers_on_sector_id"
    t.index ["sub_county_id"], name: "index_buyers_on_sub_county_id"
    t.index ["username"], name: "index_buyers_on_username"
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "buyer_id", null: false
    t.bigint "ad_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ad_id"], name: "index_cart_items_on_ad_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "ads_count", default: 0, null: false
    t.index ["ads_count"], name: "index_categories_on_ads_count"
    t.index ["name"], name: "index_categories_on_name"
  end

  create_table "categories_sellers", id: false, force: :cascade do |t|
    t.bigint "seller_id", null: false
    t.bigint "category_id", null: false
    t.index ["category_id", "seller_id"], name: "index_categories_sellers_on_category_id_and_seller_id"
  end

  create_table "click_events", force: :cascade do |t|
    t.bigint "buyer_id"
    t.bigint "ad_id"
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ad_id", "created_at"], name: "index_click_events_on_ad_id_created_at"
    t.index ["ad_id", "event_type"], name: "index_click_events_on_ad_id_event_type"
    t.index ["ad_id"], name: "index_click_events_on_ad_id"
    t.index ["event_type", "created_at"], name: "index_click_events_on_event_type_created_at"
  end

  create_table "cms_pages", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "admin_id"
    t.bigint "buyer_id"
    t.bigint "seller_id"
    t.bigint "ad_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "inquirer_seller_id"
    t.index ["ad_id", "buyer_id", "seller_id"], name: "index_conversations_on_buyer_seller_product", unique: true
    t.index ["ad_id"], name: "index_conversations_on_ad_id"
    t.index ["admin_id"], name: "index_conversations_on_admin_id"
    t.index ["buyer_id"], name: "index_conversations_on_buyer_id"
    t.index ["inquirer_seller_id"], name: "index_conversations_on_inquirer_seller_id"
    t.index ["seller_id"], name: "index_conversations_on_seller_id"
  end

  create_table "counties", force: :cascade do |t|
    t.string "name", null: false
    t.string "capital", null: false
    t.integer "county_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["county_code"], name: "index_counties_on_county_code", unique: true
    t.index ["name"], name: "index_counties_on_name", unique: true
  end

  create_table "document_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "educations", force: :cascade do |t|
    t.string "level", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["level"], name: "index_educations_on_level", unique: true
  end

  create_table "email_otps", force: :cascade do |t|
    t.string "email"
    t.string "otp_code"
    t.datetime "expires_at"
    t.boolean "verified"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "employments", force: :cascade do |t|
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_employments_on_status", unique: true
  end

  create_table "faqs", force: :cascade do |t|
    t.string "question"
    t.text "answer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "fingerprint_removal_requests", force: :cascade do |t|
    t.string "requester_name", null: false
    t.text "device_description", null: false
    t.string "device_hash", null: false
    t.text "user_agent", null: false
    t.string "status", default: "pending", null: false
    t.text "rejection_reason"
    t.datetime "approved_at"
    t.datetime "rejected_at"
    t.text "additional_info"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_fingerprint_removal_requests_on_created_at"
    t.index ["device_hash"], name: "index_fingerprint_removal_requests_on_device_hash"
    t.index ["status"], name: "index_fingerprint_removal_requests_on_status"
  end

  create_table "incomes", force: :cascade do |t|
    t.string "range", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["range"], name: "index_incomes_on_range", unique: true
  end

  create_table "internal_user_exclusions", force: :cascade do |t|
    t.string "identifier_type", null: false
    t.text "identifier_value", null: false
    t.text "reason", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "requester_name"
    t.text "device_description"
    t.text "user_agent"
    t.string "status", default: "pending"
    t.text "rejection_reason"
    t.datetime "approved_at"
    t.datetime "rejected_at"
    t.text "additional_info"
    t.index ["active"], name: "index_internal_user_exclusions_on_active"
    t.index ["approved_at"], name: "index_internal_user_exclusions_on_approved_at"
    t.index ["identifier_type", "identifier_value"], name: "index_internal_user_exclusions_on_type_and_value", unique: true
    t.index ["identifier_type"], name: "index_internal_user_exclusions_on_identifier_type"
    t.index ["rejected_at"], name: "index_internal_user_exclusions_on_rejected_at"
    t.index ["requester_name"], name: "index_internal_user_exclusions_on_requester_name"
    t.index ["status"], name: "index_internal_user_exclusions_on_status"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "sender_type", null: false
    t.bigint "sender_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "ad_id"
    t.text "product_context"
    t.string "status"
    t.datetime "read_at"
    t.datetime "delivered_at"
    t.index ["ad_id"], name: "index_messages_on_ad_id"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["sender_type", "sender_id"], name: "index_messages_on_sender"
  end

  create_table "notifications", force: :cascade do |t|
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.integer "order_id"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
  end

  create_table "password_otps", force: :cascade do |t|
    t.string "otp_digest"
    t.datetime "otp_sent_at"
    t.string "otp_purpose"
    t.string "otpable_type", null: false
    t.bigint "otpable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["otpable_type", "otpable_id"], name: "index_password_otps_on_otpable"
  end

  create_table "payment_transactions", force: :cascade do |t|
    t.bigint "seller_id", null: false
    t.bigint "tier_id", null: false
    t.bigint "tier_pricing_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "phone_number", null: false
    t.string "status", default: "initiated", null: false
    t.string "transaction_type", default: "tier_upgrade", null: false
    t.string "checkout_request_id", null: false
    t.string "merchant_request_id", null: false
    t.string "mpesa_receipt_number"
    t.string "transaction_date"
    t.string "callback_phone_number"
    t.decimal "callback_amount", precision: 10, scale: 2
    t.string "stk_response_code"
    t.string "stk_response_description"
    t.text "error_message"
    t.datetime "completed_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checkout_request_id"], name: "index_payment_transactions_on_checkout_request_id", unique: true
    t.index ["created_at"], name: "index_payment_transactions_on_created_at"
    t.index ["merchant_request_id"], name: "index_payment_transactions_on_merchant_request_id", unique: true
    t.index ["seller_id"], name: "index_payment_transactions_on_seller_id"
    t.index ["status"], name: "index_payment_transactions_on_status"
    t.index ["tier_id"], name: "index_payment_transactions_on_tier_id"
    t.index ["tier_pricing_id"], name: "index_payment_transactions_on_tier_pricing_id"
  end

  create_table "payments", force: :cascade do |t|
    t.string "transaction_type"
    t.string "trans_id"
    t.string "trans_time"
    t.decimal "trans_amount"
    t.string "business_short_code"
    t.string "bill_ref_number"
    t.string "invoice_number"
    t.string "org_account_balance"
    t.string "third_party_trans_id"
    t.string "msisdn"
    t.string "first_name"
    t.string "middle_name"
    t.string "last_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "playing_with_neon", id: :serial, force: :cascade do |t|
    t.text "name", null: false
    t.float "value", limit: 24
  end

  create_table "promotions", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.decimal "discount_percentage"
    t.string "coupon_code"
    t.datetime "start_date"
    t.datetime "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "ad_id", null: false
    t.bigint "buyer_id", null: false
    t.integer "rating", limit: 2, null: false
    t.text "review"
    t.text "reply"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "seller_reply"
    t.index ["ad_id", "rating"], name: "index_reviews_on_ad_id_rating"
    t.index ["ad_id"], name: "index_reviews_on_ad_id"
    t.index ["buyer_id"], name: "index_reviews_on_buyer_id"
  end

  create_table "riders", force: :cascade do |t|
    t.string "full_name"
    t.string "phone_number"
    t.bigint "age_group_id", null: false
    t.string "email"
    t.string "id_number"
    t.string "driving_license"
    t.string "vehicle_type"
    t.string "license_plate"
    t.string "physical_address"
    t.string "gender", default: "Male"
    t.boolean "blocked", default: false
    t.string "password_digest"
    t.string "kin_full_name"
    t.string "kin_relationship"
    t.string "kin_phone_number"
    t.bigint "county_id", null: false
    t.bigint "sub_county_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["age_group_id"], name: "index_riders_on_age_group_id"
    t.index ["county_id"], name: "index_riders_on_county_id"
    t.index ["sub_county_id"], name: "index_riders_on_sub_county_id"
  end

  create_table "sales_users", force: :cascade do |t|
    t.string "fullname"
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sectors", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_sectors_on_name", unique: true
  end

  create_table "seller_documents", force: :cascade do |t|
    t.bigint "seller_id", null: false
    t.bigint "document_type_id", null: false
    t.string "document_url"
    t.date "document_expiry_date"
    t.boolean "document_verified", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_type_id"], name: "index_seller_documents_on_document_type_id"
    t.index ["seller_id", "document_type_id"], name: "index_seller_documents_on_seller_id_and_document_type_id", unique: true
    t.index ["seller_id"], name: "index_seller_documents_on_seller_id"
  end

  create_table "seller_tiers", force: :cascade do |t|
    t.bigint "seller_id", null: false
    t.bigint "tier_id", null: false
    t.integer "duration_months", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "expires_at"
    t.bigint "payment_transaction_id"
    t.index ["expires_at"], name: "index_seller_tiers_on_expires_at"
    t.index ["payment_transaction_id"], name: "index_seller_tiers_on_payment_transaction_id"
    t.index ["seller_id", "tier_id"], name: "index_seller_tiers_on_seller_id_tier_id"
    t.index ["seller_id"], name: "index_seller_tiers_on_seller_id"
    t.index ["tier_id"], name: "index_seller_tiers_on_tier_id"
  end

  create_table "sellers", id: :bigint, default: -> { "nextval('vendors_id_seq'::regclass)" }, force: :cascade do |t|
    t.string "fullname"
    t.string "username"
    t.string "description"
    t.string "phone_number", limit: 10
    t.string "location"
    t.string "business_registration_number"
    t.string "enterprise_name"
    t.bigint "county_id", null: false
    t.bigint "sub_county_id", null: false
    t.string "email"
    t.string "profile_picture"
    t.bigint "age_group_id", null: false
    t.string "zipcode"
    t.string "city"
    t.string "gender", default: "Male"
    t.boolean "blocked", default: false
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "document_url"
    t.boolean "deleted", default: false, null: false
    t.bigint "document_type_id"
    t.date "document_expiry_date"
    t.boolean "document_verified", default: false
    t.integer "ads_count", default: 0, null: false
    t.index "lower((email)::text)", name: "index_vendors_on_lower_email", unique: true
    t.index "lower((enterprise_name)::text)", name: "index_sellers_on_lower_enterprise_name", unique: true
    t.index ["ads_count"], name: "index_sellers_on_ads_count"
    t.index ["age_group_id"], name: "index_sellers_on_age_group_id"
    t.index ["blocked"], name: "index_sellers_on_blocked"
    t.index ["business_registration_number"], name: "index_sellers_on_business_registration_number", unique: true, where: "((business_registration_number IS NOT NULL) AND ((business_registration_number)::text <> ''::text))"
    t.index ["county_id"], name: "index_sellers_on_county_id"
    t.index ["document_type_id"], name: "index_sellers_on_document_type_id"
    t.index ["phone_number"], name: "index_sellers_on_phone_number", unique: true
    t.index ["sub_county_id"], name: "index_sellers_on_sub_county_id"
    t.index ["username"], name: "index_sellers_on_username", unique: true, where: "((username IS NOT NULL) AND ((username)::text <> ''::text))"
  end

  create_table "sub_counties", force: :cascade do |t|
    t.string "name", null: false
    t.integer "sub_county_code", null: false
    t.bigint "county_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["county_id"], name: "index_sub_counties_on_county_id"
  end

  create_table "subcategories", force: :cascade do |t|
    t.string "name"
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "ads_count", default: 0, null: false
    t.index ["ads_count"], name: "index_subcategories_on_ads_count"
    t.index ["category_id", "name"], name: "index_subcategories_on_category_id_name"
  end

  create_table "tier_features", force: :cascade do |t|
    t.bigint "tier_id", null: false
    t.string "feature_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tier_id"], name: "index_tier_features_on_tier_id"
  end

  create_table "tier_pricings", force: :cascade do |t|
    t.bigint "tier_id", null: false
    t.integer "duration_months", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tier_id"], name: "index_tier_pricings_on_tier_id"
  end

  create_table "tiers", force: :cascade do |t|
    t.string "name", null: false
    t.integer "ads_limit", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "vehicle_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "wish_lists", force: :cascade do |t|
    t.bigint "buyer_id"
    t.bigint "ad_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "seller_id"
    t.index ["ad_id"], name: "index_wish_lists_on_ad_id"
    t.index ["buyer_id"], name: "index_wish_lists_on_purchaser_id"
    t.index ["seller_id"], name: "index_wish_lists_on_seller_id"
    t.check_constraint "buyer_id IS NOT NULL OR seller_id IS NOT NULL", name: "wish_lists_user_check"
  end

  add_foreign_key "ad_searches", "buyers"
  add_foreign_key "ads", "categories"
  add_foreign_key "ads", "sellers"
  add_foreign_key "ads", "subcategories"
  add_foreign_key "buyers", "age_groups"
  add_foreign_key "buyers", "counties"
  add_foreign_key "buyers", "educations"
  add_foreign_key "buyers", "employments"
  add_foreign_key "buyers", "incomes"
  add_foreign_key "buyers", "sectors"
  add_foreign_key "buyers", "sub_counties"
  add_foreign_key "cart_items", "ads"
  add_foreign_key "cart_items", "buyers"
  add_foreign_key "click_events", "ads"
  add_foreign_key "click_events", "buyers"
  add_foreign_key "conversations", "admins"
  add_foreign_key "conversations", "ads"
  add_foreign_key "conversations", "buyers"
  add_foreign_key "conversations", "sellers"
  add_foreign_key "conversations", "sellers", column: "inquirer_seller_id"
  add_foreign_key "messages", "ads", on_delete: :nullify
  add_foreign_key "messages", "conversations"
  add_foreign_key "payment_transactions", "sellers"
  add_foreign_key "payment_transactions", "tier_pricings"
  add_foreign_key "payment_transactions", "tiers"
  add_foreign_key "reviews", "ads"
  add_foreign_key "reviews", "buyers"
  add_foreign_key "riders", "age_groups"
  add_foreign_key "riders", "counties"
  add_foreign_key "riders", "sub_counties"
  add_foreign_key "seller_documents", "document_types"
  add_foreign_key "seller_documents", "sellers"
  add_foreign_key "seller_tiers", "sellers"
  add_foreign_key "seller_tiers", "tiers"
  add_foreign_key "sellers", "age_groups"
  add_foreign_key "sellers", "counties"
  add_foreign_key "sellers", "document_types"
  add_foreign_key "sellers", "sub_counties"
  add_foreign_key "sub_counties", "counties"
  add_foreign_key "tier_features", "tiers"
  add_foreign_key "tier_pricings", "tiers"
  add_foreign_key "wish_lists", "ads"
  add_foreign_key "wish_lists", "buyers"
  add_foreign_key "wish_lists", "sellers"
end
