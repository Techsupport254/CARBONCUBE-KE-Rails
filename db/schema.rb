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

ActiveRecord::Schema[8.0].define(version: 2025_08_27_082710) do
  # These are extensions that must be enabled in order to support this database
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
    t.integer "quantity"
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
    t.index ["category_id"], name: "index_ads_on_category_id"
    t.index ["description"], name: "index_ads_on_description", opclass: :gin_trgm_ops, using: :gin
    t.index ["reviews_count"], name: "index_ads_on_reviews_count"
    t.index ["seller_id"], name: "index_ads_on_seller_id"
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

  create_table "buy_for_me_order_cart_items", force: :cascade do |t|
    t.bigint "buyer_id", null: false
    t.bigint "ad_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ad_id"], name: "index_buy_for_me_order_cart_items_on_ad_id"
    t.index ["buyer_id"], name: "index_buy_for_me_order_cart_items_on_buyer_id"
  end

  create_table "buy_for_me_order_items", force: :cascade do |t|
    t.bigint "buy_for_me_order_id", null: false
    t.bigint "ad_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "total_price", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["ad_id"], name: "index_buy_for_me_order_items_on_ad_id"
    t.index ["buy_for_me_order_id"], name: "index_buy_for_me_order_items_on_buy_for_me_order_id"
  end

  create_table "buy_for_me_order_sellers", force: :cascade do |t|
    t.bigint "buy_for_me_order_id", null: false
    t.bigint "seller_id", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["buy_for_me_order_id"], name: "index_buy_for_me_order_sellers_on_buy_for_me_order_id"
    t.index ["seller_id"], name: "index_buy_for_me_order_sellers_on_seller_id"
  end

  create_table "buy_for_me_orders", force: :cascade do |t|
    t.bigint "buyer_id", null: false
    t.decimal "total_amount", precision: 10, scale: 2
    t.decimal "processing_fee", precision: 10, scale: 2
    t.decimal "delivery_fee", precision: 10, scale: 2
    t.string "mpesa_transaction_code"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["buyer_id"], name: "index_buy_for_me_orders_on_buyer_id"
  end

  create_table "buyers", force: :cascade do |t|
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
    t.index "lower((email)::text)", name: "index_buyers_on_lower_email", unique: true
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
    t.index ["buyer_id"], name: "index_cart_items_on_buyer_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name"
  end

  create_table "categories_sellers", id: false, force: :cascade do |t|
    t.bigint "seller_id", null: false
    t.bigint "category_id", null: false
    t.index ["category_id", "seller_id"], name: "index_categories_sellers_on_category_id_and_seller_id"
    t.index ["seller_id", "category_id"], name: "index_categories_sellers_on_seller_id_and_category_id"
  end

  create_table "click_events", force: :cascade do |t|
    t.bigint "buyer_id"
    t.bigint "ad_id"
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ad_id"], name: "index_click_events_on_ad_id"
    t.index ["buyer_id"], name: "index_click_events_on_buyer_id"
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
    t.index ["ad_id"], name: "index_conversations_on_ad_id"
    t.index ["admin_id"], name: "index_conversations_on_admin_id"
    t.index ["buyer_id", "seller_id", "ad_id"], name: "index_conversations_on_buyer_seller_product", unique: true
    t.index ["buyer_id"], name: "index_conversations_on_buyer_id"
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

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "ad_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "total_price", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["ad_id"], name: "index_order_items_on_ad_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
  end

  create_table "order_sellers", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "seller_id", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["order_id"], name: "index_order_sellers_on_order_id"
    t.index ["seller_id"], name: "index_order_sellers_on_seller_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "buyer_id", null: false
    t.string "status", default: "Processing"
    t.decimal "total_amount", precision: 10, scale: 2
    t.decimal "processing_fee", precision: 10, scale: 2
    t.decimal "delivery_fee", precision: 10, scale: 2
    t.string "mpesa_transaction_code"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["buyer_id"], name: "index_orders_on_buyer_id"
  end

  create_table "password_otps", force: :cascade do |t|
    t.string "otp_digest", null: false
    t.datetime "otp_sent_at", null: false
    t.string "otp_purpose", default: "password_reset", null: false
    t.string "otpable_type", null: false
    t.bigint "otpable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["otpable_type", "otpable_id"], name: "index_password_otps_on_otpable"
    t.index ["otpable_type", "otpable_id"], name: "index_password_otps_on_otpable_type_and_otpable_id"
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

  create_table "seller_tiers", force: :cascade do |t|
    t.bigint "seller_id", null: false
    t.bigint "tier_id", null: false
    t.integer "duration_months", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["seller_id"], name: "index_seller_tiers_on_seller_id"
    t.index ["tier_id"], name: "index_seller_tiers_on_tier_id"
  end

  create_table "sellers", force: :cascade do |t|
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
    t.index "lower((email)::text)", name: "index_sellers_on_lower_email", unique: true
    t.index ["age_group_id"], name: "index_sellers_on_age_group_id"
    t.index ["county_id"], name: "index_sellers_on_county_id"
    t.index ["document_type_id"], name: "index_sellers_on_document_type_id"
    t.index ["sub_county_id"], name: "index_sellers_on_sub_county_id"
  end

  create_table "shipments", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "carrier"
    t.string "tracking_number"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_shipments_on_order_id"
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
    t.bigint "buyer_id", null: false
    t.bigint "ad_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ad_id"], name: "index_wish_lists_on_ad_id"
    t.index ["buyer_id"], name: "index_wish_lists_on_buyer_id"
  end

  add_foreign_key "ad_searches", "buyers"
  add_foreign_key "ads", "categories"
  add_foreign_key "ads", "sellers"
  add_foreign_key "ads", "subcategories"
  add_foreign_key "buy_for_me_order_cart_items", "ads"
  add_foreign_key "buy_for_me_order_cart_items", "buyers"
  add_foreign_key "buy_for_me_order_items", "ads"
  add_foreign_key "buy_for_me_order_items", "buy_for_me_orders"
  add_foreign_key "buy_for_me_order_sellers", "buy_for_me_orders"
  add_foreign_key "buy_for_me_order_sellers", "sellers"
  add_foreign_key "buy_for_me_orders", "buyers"
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
  add_foreign_key "messages", "conversations"
  add_foreign_key "order_items", "ads"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_sellers", "orders"
  add_foreign_key "order_sellers", "sellers"
  add_foreign_key "orders", "buyers"
  add_foreign_key "reviews", "ads"
  add_foreign_key "reviews", "buyers"
  add_foreign_key "riders", "age_groups"
  add_foreign_key "riders", "counties"
  add_foreign_key "riders", "sub_counties"
  add_foreign_key "seller_tiers", "sellers"
  add_foreign_key "seller_tiers", "tiers"
  add_foreign_key "sellers", "age_groups"
  add_foreign_key "sellers", "counties"
  add_foreign_key "sellers", "document_types"
  add_foreign_key "sellers", "sub_counties"
  add_foreign_key "shipments", "orders"
  add_foreign_key "sub_counties", "counties"
  add_foreign_key "tier_features", "tiers"
  add_foreign_key "tier_pricings", "tiers"
  add_foreign_key "wish_lists", "ads"
  add_foreign_key "wish_lists", "buyers"
end
