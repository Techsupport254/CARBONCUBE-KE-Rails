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

ActiveRecord::Schema[7.1].define(version: 2025_11_13_082100) do
  create_schema "auth"
  create_schema "extensions"
  create_schema "graphql"
  create_schema "graphql_public"
  create_schema "pgbouncer"
  create_schema "realtime"
  create_schema "storage"
  create_schema "vault"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_stat_statements"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "buyer_id"
    t.index ["buyer_id"], name: "index_ad_searches_on_buyer_id"
  end

  create_table "admins", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "fullname"
    t.string "username"
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "oauth_token"
    t.string "oauth_refresh_token"
    t.string "oauth_expires_at"
    t.index ["id"], name: "index_admins_on_uuid", unique: true
  end

  create_table "ads", force: :cascade do |t|
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
    t.string "google_merchant_product_id"
    t.uuid "seller_id", null: false
    t.index ["category_id", "deleted", "flagged", "created_at"], name: "index_ads_on_category_deleted_flagged_created_at"
    t.index ["category_id", "deleted", "flagged"], name: "index_ads_on_category_deleted_flagged"
    t.index ["category_id"], name: "index_ads_on_category_id"
    t.index ["deleted", "flagged", "created_at"], name: "index_ads_on_deleted_flagged_created_at"
    t.index ["deleted", "flagged", "created_at"], name: "index_ads_on_deleted_flagged_created_at_perf"
    t.index ["deleted", "flagged", "seller_id", "created_at", "id"], name: "index_ads_best_sellers_perf"
    t.index ["deleted", "flagged", "seller_id", "created_at"], name: "index_ads_on_deleted_flagged_seller_created_at"
    t.index ["deleted", "flagged", "subcategory_id", "created_at"], name: "index_ads_on_deleted_flagged_subcategory_created_at"
    t.index ["reviews_count"], name: "index_ads_on_reviews_count"
    t.index ["seller_id", "deleted", "flagged"], name: "index_ads_on_seller_deleted_flagged"
    t.index ["seller_id"], name: "index_ads_on_seller_id"
    t.index ["subcategory_id", "deleted", "flagged", "created_at"], name: "index_ads_on_subcategory_deleted_flagged_created_at"
    t.index ["subcategory_id", "deleted", "flagged"], name: "index_ads_on_subcategory_deleted_flagged"
    t.index ["subcategory_id"], name: "index_ads_on_subcategory_id"
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
    t.string "utm_content"
    t.string "utm_term"
  end

  create_table "banners", force: :cascade do |t|
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "best_sellers_caches", force: :cascade do |t|
    t.string "cache_key", null: false
    t.jsonb "data", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cache_key"], name: "index_best_sellers_caches_on_cache_key", unique: true
    t.index ["expires_at"], name: "index_best_sellers_caches_on_expires_at"
  end

  create_table "buyers", id: :uuid, default: nil, force: :cascade do |t|
    t.string "fullname", null: false
    t.string "username", null: false
    t.string "password_digest"
    t.string "email", null: false
    t.string "phone_number", limit: 10
    t.bigint "age_group_id"
    t.string "zipcode"
    t.string "city"
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
    t.string "provider"
    t.string "uid"
    t.string "oauth_token"
    t.string "oauth_refresh_token"
    t.string "oauth_expires_at"
    t.text "description"
    t.datetime "last_active_at"
    t.index "lower((email)::text)", name: "index_purchasers_on_lower_email", unique: true
    t.index ["age_group_id"], name: "index_buyers_on_age_group_id"
    t.index ["county_id"], name: "index_buyers_on_county_id"
    t.index ["education_id"], name: "index_buyers_on_education_id"
    t.index ["employment_id"], name: "index_buyers_on_employment_id"
    t.index ["id"], name: "index_buyers_on_uuid", unique: true
    t.index ["income_id"], name: "index_buyers_on_income_id"
    t.index ["phone_number"], name: "index_buyers_on_phone_number", unique: true, where: "(phone_number IS NOT NULL)"
    t.index ["sector_id"], name: "index_buyers_on_sector_id"
    t.index ["sub_county_id"], name: "index_buyers_on_sub_county_id"
    t.index ["username"], name: "index_buyers_on_username"
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "ad_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "buyer_id", null: false
    t.index ["ad_id"], name: "index_cart_items_on_ad_id"
    t.index ["buyer_id"], name: "index_cart_items_on_buyer_id"
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
    t.bigint "category_id", null: false
    t.uuid "seller_id", null: false
    t.index ["category_id", "seller_id"], name: "index_categories_sellers_on_category_id_and_seller_id"
    t.index ["seller_id"], name: "index_categories_sellers_on_seller_id"
  end

  create_table "click_events", force: :cascade do |t|
    t.bigint "ad_id"
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "buyer_id"
    t.index ["ad_id", "created_at"], name: "index_click_events_on_ad_id_created_at"
    t.index ["ad_id", "event_type"], name: "index_click_events_on_ad_id_event_type"
    t.index ["ad_id"], name: "index_click_events_on_ad_id"
    t.index ["buyer_id", "created_at"], name: "index_click_events_on_buyer_id_created_at"
    t.index ["buyer_id"], name: "index_click_events_on_buyer_id"
    t.index ["created_at", "event_type"], name: "index_click_events_on_created_at_event_type"
    t.index ["event_type", "created_at"], name: "index_click_events_on_event_type_created_at"
    t.index ["metadata"], name: "index_click_events_on_metadata", using: :gin
  end

  create_table "cms_pages", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "conversations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "ad_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "seller_id"
    t.uuid "inquirer_seller_id"
    t.uuid "buyer_id"
    t.uuid "admin_id"
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

  create_table "data_deletion_requests", force: :cascade do |t|
    t.string "full_name", null: false
    t.string "email", null: false
    t.string "phone"
    t.string "account_type", null: false
    t.text "reason"
    t.string "status", default: "pending", null: false
    t.string "token", null: false
    t.datetime "requested_at", null: false
    t.datetime "verified_at"
    t.datetime "processed_at"
    t.text "rejection_reason"
    t.text "admin_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_data_deletion_requests_on_email"
    t.index ["requested_at"], name: "index_data_deletion_requests_on_requested_at"
    t.index ["status"], name: "index_data_deletion_requests_on_status"
    t.index ["token"], name: "index_data_deletion_requests_on_token", unique: true
  end

  create_table "device_fingerprints", force: :cascade do |t|
    t.string "device_id"
    t.text "hardware_fingerprint"
    t.text "user_agent"
    t.datetime "last_seen"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_device_fingerprints_on_device_id", unique: true
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
    t.boolean "verified", default: false
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

  create_table "issue_attachments", force: :cascade do |t|
    t.bigint "issue_id", null: false
    t.string "file_name", null: false
    t.integer "file_size", null: false
    t.string "file_type", null: false
    t.string "file_url", null: false
    t.string "uploaded_by_type", null: false
    t.uuid "uploaded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_issue_attachments_on_created_at"
    t.index ["file_type"], name: "index_issue_attachments_on_file_type"
    t.index ["issue_id"], name: "index_issue_attachments_on_issue_id"
    t.index ["uploaded_by_type", "uploaded_by_id"], name: "index_issue_attachments_on_uploaded_by"
    t.index ["uploaded_by_type", "uploaded_by_id"], name: "index_issue_attachments_on_uploaded_by_type_and_uploaded_by_id"
  end

  create_table "issue_comments", force: :cascade do |t|
    t.bigint "issue_id", null: false
    t.text "content", null: false
    t.string "author_type", null: false
    t.uuid "author_id"
    t.boolean "is_internal", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_issue_comments_on_author"
    t.index ["author_type", "author_id"], name: "index_issue_comments_on_author_type_and_author_id"
    t.index ["created_at"], name: "index_issue_comments_on_created_at"
    t.index ["is_internal"], name: "index_issue_comments_on_is_internal"
    t.index ["issue_id"], name: "index_issue_comments_on_issue_id"
  end

  create_table "issues", force: :cascade do |t|
    t.string "title", limit: 200, null: false
    t.text "description", null: false
    t.string "reporter_name", limit: 100, null: false
    t.string "reporter_email", null: false
    t.integer "status", default: 0, null: false
    t.integer "priority", default: 1, null: false
    t.integer "category", default: 0, null: false
    t.boolean "public_visible", default: true
    t.datetime "resolved_at", precision: nil
    t.text "resolution_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "device_uuid", null: false
    t.uuid "user_id"
    t.string "user_type"
    t.uuid "assigned_to_id"
    t.index ["assigned_to_id"], name: "index_issues_on_assigned_to_id"
    t.index ["category", "status"], name: "index_issues_on_category_and_status"
    t.index ["category"], name: "index_issues_on_category"
    t.index ["created_at"], name: "index_issues_on_created_at"
    t.index ["device_uuid"], name: "index_issues_on_device_uuid"
    t.index ["priority"], name: "index_issues_on_priority"
    t.index ["public_visible"], name: "index_issues_on_public_visible"
    t.index ["reporter_email"], name: "index_issues_on_reporter_email"
    t.index ["status", "priority"], name: "index_issues_on_status_and_priority"
    t.index ["status"], name: "index_issues_on_status"
    t.index ["user_id", "user_type"], name: "index_issues_on_user_id_and_user_type"
    t.index ["user_id"], name: "index_issues_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.uuid "conversation_id", null: false
    t.string "sender_type", null: false
    t.uuid "sender_id", null: false
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

  create_table "offer_ads", force: :cascade do |t|
    t.bigint "offer_id", null: false
    t.bigint "ad_id", null: false
    t.decimal "discount_percentage", precision: 5, scale: 2, null: false
    t.decimal "original_price", precision: 10, scale: 2, null: false
    t.decimal "discounted_price", precision: 10, scale: 2, null: false
    t.boolean "is_active", default: true, null: false
    t.text "seller_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ad_id"], name: "index_offer_ads_on_ad_id"
    t.index ["discount_percentage"], name: "index_offer_ads_on_discount_percentage"
    t.index ["is_active"], name: "index_offer_ads_on_is_active"
    t.index ["offer_id", "ad_id"], name: "index_offer_ads_on_offer_id_and_ad_id", unique: true
    t.index ["offer_id", "is_active"], name: "index_offer_ads_on_offer_id_and_is_active"
    t.index ["offer_id"], name: "index_offer_ads_on_offer_id"
  end

  create_table "offers", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "offer_type", null: false
    t.string "status", default: "draft"
    t.string "banner_color", default: "#dc2626"
    t.string "badge_color", default: "#fbbf24"
    t.string "icon_name"
    t.text "banner_image_url"
    t.text "hero_image_url"
    t.datetime "start_time"
    t.datetime "end_time"
    t.boolean "is_recurring", default: false
    t.string "recurrence_pattern"
    t.json "recurrence_config"
    t.decimal "discount_percentage", precision: 5, scale: 2
    t.decimal "fixed_discount_amount", precision: 10, scale: 2
    t.string "discount_type"
    t.json "discount_config"
    t.json "target_categories"
    t.json "target_sellers"
    t.json "target_products"
    t.string "eligibility_criteria"
    t.decimal "minimum_order_amount", precision: 10, scale: 2
    t.integer "max_uses_per_customer"
    t.integer "total_usage_limit"
    t.integer "priority", default: 0
    t.boolean "featured", default: false
    t.boolean "show_on_homepage", default: true
    t.boolean "show_badge", default: true
    t.string "badge_text", default: "SALE"
    t.text "cta_text", default: "Shop Now"
    t.text "terms_and_conditions"
    t.integer "view_count", default: 0
    t.integer "click_count", default: 0
    t.integer "conversion_count", default: 0
    t.decimal "revenue_generated", precision: 12, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "seller_id", null: false
    t.index ["end_time"], name: "index_offers_on_end_time"
    t.index ["featured"], name: "index_offers_on_featured"
    t.index ["offer_type"], name: "index_offers_on_offer_type"
    t.index ["priority"], name: "index_offers_on_priority"
    t.index ["seller_id"], name: "index_offers_on_seller_id"
    t.index ["start_time"], name: "index_offers_on_start_time"
    t.index ["status", "start_time", "end_time"], name: "index_offers_on_status_and_start_time_and_end_time"
    t.index ["status"], name: "index_offers_on_status"
  end

  create_table "password_otps", force: :cascade do |t|
    t.string "otp_digest"
    t.datetime "otp_sent_at"
    t.string "otp_purpose"
    t.string "otpable_type", null: false
    t.uuid "otpable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["otpable_type", "otpable_id"], name: "index_password_otps_on_otpable"
  end

  create_table "payment_transactions", force: :cascade do |t|
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
    t.uuid "seller_id", null: false
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
    t.float "value"
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

  create_table "quarterly_targets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "metric_type", null: false
    t.integer "year", null: false
    t.integer "quarter", null: false
    t.integer "target_value", null: false
    t.string "status", default: "pending", null: false
    t.uuid "created_by_id", null: false
    t.uuid "approved_by_id"
    t.datetime "approved_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_quarterly_targets_on_approved_by_id"
    t.index ["created_by_id"], name: "index_quarterly_targets_on_created_by_id"
    t.index ["metric_type", "year", "quarter"], name: "index_quarterly_targets_on_metric_year_quarter", unique: true
    t.index ["status"], name: "index_quarterly_targets_on_status"
    t.index ["year", "quarter"], name: "index_quarterly_targets_on_year_and_quarter"
  end

  create_table "review_requests", force: :cascade do |t|
    t.uuid "seller_id", null: false
    t.text "reason"
    t.string "status", default: "pending"
    t.datetime "requested_at"
    t.datetime "reviewed_at"
    t.string "reviewed_by_type"
    t.uuid "reviewed_by_id"
    t.text "review_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["requested_at"], name: "index_review_requests_on_requested_at"
    t.index ["reviewed_by_type", "reviewed_by_id"], name: "index_review_requests_on_reviewed_by"
    t.index ["seller_id"], name: "index_review_requests_on_seller_id"
    t.index ["status"], name: "index_review_requests_on_status"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "ad_id", null: false
    t.integer "rating", limit: 2, null: false
    t.text "review"
    t.text "reply"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "seller_reply"
    t.json "images", default: []
    t.uuid "buyer_id", null: false
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
    t.string "provider"
    t.string "uid"
    t.string "oauth_token"
    t.string "oauth_refresh_token"
    t.string "oauth_expires_at"
    t.index ["age_group_id"], name: "index_riders_on_age_group_id"
    t.index ["county_id"], name: "index_riders_on_county_id"
    t.index ["sub_county_id"], name: "index_riders_on_sub_county_id"
  end

  create_table "sales_users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "fullname"
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "oauth_token"
    t.string "oauth_refresh_token"
    t.string "oauth_expires_at"
    t.index ["id"], name: "index_sales_users_on_uuid", unique: true
  end

  create_table "sectors", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_sectors_on_name", unique: true
  end

  create_table "seller_documents", force: :cascade do |t|
    t.bigint "document_type_id", null: false
    t.string "document_url"
    t.date "document_expiry_date"
    t.boolean "document_verified", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "seller_id", null: false
    t.index ["document_type_id"], name: "index_seller_documents_on_document_type_id"
    t.index ["seller_id", "document_type_id"], name: "index_seller_documents_on_seller_id_and_document_type_id", unique: true
    t.index ["seller_id"], name: "index_seller_documents_on_seller_id"
  end

  create_table "seller_tiers", force: :cascade do |t|
    t.bigint "tier_id", null: false
    t.integer "duration_months", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "expires_at"
    t.bigint "payment_transaction_id"
    t.uuid "seller_id", null: false
    t.index ["expires_at"], name: "index_seller_tiers_on_expires_at"
    t.index ["payment_transaction_id"], name: "index_seller_tiers_on_payment_transaction_id"
    t.index ["seller_id", "tier_id"], name: "index_seller_tiers_on_seller_id_tier_id"
    t.index ["seller_id"], name: "index_seller_tiers_on_seller_id"
    t.index ["tier_id"], name: "index_seller_tiers_on_tier_id"
  end

  create_table "sellers", id: :uuid, default: nil, force: :cascade do |t|
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
    t.bigint "age_group_id"
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
    t.datetime "last_active_at"
    t.string "provider"
    t.string "uid"
    t.string "oauth_token"
    t.string "oauth_refresh_token"
    t.string "oauth_expires_at"
    t.boolean "flagged", default: false, null: false
    t.index "lower((email)::text)", name: "index_vendors_on_lower_email", unique: true
    t.index "lower((enterprise_name)::text)", name: "index_sellers_on_lower_enterprise_name", unique: true
    t.index ["ads_count"], name: "index_sellers_on_ads_count"
    t.index ["age_group_id"], name: "index_sellers_on_age_group_id"
    t.index ["blocked"], name: "index_sellers_on_blocked"
    t.index ["business_registration_number"], name: "index_sellers_on_business_registration_number", unique: true, where: "((business_registration_number IS NOT NULL) AND ((business_registration_number)::text <> ''::text))"
    t.index ["county_id"], name: "index_sellers_on_county_id"
    t.index ["document_type_id"], name: "index_sellers_on_document_type_id"
    t.index ["id"], name: "index_sellers_on_uuid", unique: true
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

  create_table "visitors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "visitor_id", null: false
    t.string "device_fingerprint_hash"
    t.string "first_source"
    t.string "first_referrer"
    t.string "first_utm_source"
    t.string "first_utm_medium"
    t.string "first_utm_campaign"
    t.string "first_utm_content"
    t.string "first_utm_term"
    t.string "ip_address"
    t.string "country"
    t.string "city"
    t.string "region"
    t.string "timezone"
    t.jsonb "device_info", default: {}
    t.string "user_agent"
    t.datetime "first_visit_at", null: false
    t.datetime "last_visit_at", null: false
    t.integer "visit_count", default: 1, null: false
    t.boolean "has_clicked_ad", default: false
    t.datetime "first_ad_click_at"
    t.datetime "last_ad_click_at"
    t.integer "ad_click_count", default: 0
    t.boolean "is_internal_user", default: false
    t.uuid "registered_user_id"
    t.string "registered_user_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_fingerprint_hash"], name: "index_visitors_on_device_fingerprint_hash"
    t.index ["first_source"], name: "index_visitors_on_first_source"
    t.index ["first_visit_at"], name: "index_visitors_on_first_visit_at"
    t.index ["has_clicked_ad"], name: "index_visitors_on_has_clicked_ad"
    t.index ["ip_address"], name: "index_visitors_on_ip_address"
    t.index ["is_internal_user"], name: "index_visitors_on_is_internal_user"
    t.index ["last_visit_at"], name: "index_visitors_on_last_visit_at"
    t.index ["registered_user_id", "registered_user_type"], name: "index_visitors_on_registered_user_id_and_registered_user_type"
    t.index ["visitor_id"], name: "index_visitors_on_visitor_id", unique: true
  end

  create_table "wish_lists", force: :cascade do |t|
    t.bigint "ad_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "seller_id"
    t.uuid "buyer_id"
    t.index ["ad_id"], name: "index_wish_lists_on_ad_id"
    t.index ["buyer_id"], name: "index_wish_lists_on_buyer_id"
    t.index ["seller_id"], name: "index_wish_lists_on_seller_id"
  end

  add_foreign_key "ad_searches", "buyers", on_delete: :cascade
  add_foreign_key "ad_searches", "buyers", on_delete: :cascade
  add_foreign_key "ads", "categories"
  add_foreign_key "ads", "sellers", on_delete: :cascade
  add_foreign_key "ads", "sellers", on_delete: :cascade
  add_foreign_key "ads", "subcategories"
  add_foreign_key "buyers", "age_groups"
  add_foreign_key "buyers", "counties"
  add_foreign_key "buyers", "educations"
  add_foreign_key "buyers", "employments"
  add_foreign_key "buyers", "incomes"
  add_foreign_key "buyers", "sectors"
  add_foreign_key "buyers", "sub_counties"
  add_foreign_key "cart_items", "ads"
  add_foreign_key "cart_items", "buyers", on_delete: :cascade
  add_foreign_key "cart_items", "buyers", on_delete: :cascade
  add_foreign_key "click_events", "ads"
  add_foreign_key "click_events", "buyers", on_delete: :cascade
  add_foreign_key "click_events", "buyers", on_delete: :cascade
  add_foreign_key "conversations", "admins", on_delete: :cascade
  add_foreign_key "conversations", "admins", on_delete: :cascade
  add_foreign_key "conversations", "ads"
  add_foreign_key "conversations", "buyers", on_delete: :cascade
  add_foreign_key "conversations", "buyers", on_delete: :cascade
  add_foreign_key "conversations", "sellers", column: "inquirer_seller_id", on_delete: :cascade
  add_foreign_key "conversations", "sellers", column: "inquirer_seller_id", on_delete: :cascade
  add_foreign_key "conversations", "sellers", on_delete: :cascade
  add_foreign_key "conversations", "sellers", on_delete: :cascade
  add_foreign_key "issue_attachments", "issues"
  add_foreign_key "issue_comments", "issues"
  add_foreign_key "issues", "admins", column: "assigned_to_id", on_delete: :cascade
  add_foreign_key "issues", "admins", column: "assigned_to_id", on_delete: :cascade
  add_foreign_key "messages", "ads", on_delete: :nullify
  add_foreign_key "messages", "conversations", on_delete: :cascade
  add_foreign_key "offer_ads", "ads"
  add_foreign_key "offer_ads", "offers"
  add_foreign_key "offers", "sellers", on_delete: :cascade
  add_foreign_key "offers", "sellers", on_delete: :cascade
  add_foreign_key "payment_transactions", "sellers", on_delete: :cascade
  add_foreign_key "payment_transactions", "sellers", on_delete: :cascade
  add_foreign_key "payment_transactions", "tier_pricings"
  add_foreign_key "payment_transactions", "tiers"
  add_foreign_key "review_requests", "sellers"
  add_foreign_key "reviews", "ads"
  add_foreign_key "reviews", "buyers", on_delete: :cascade
  add_foreign_key "reviews", "buyers", on_delete: :cascade
  add_foreign_key "riders", "age_groups"
  add_foreign_key "riders", "counties"
  add_foreign_key "riders", "sub_counties"
  add_foreign_key "seller_documents", "document_types"
  add_foreign_key "seller_documents", "sellers", on_delete: :cascade
  add_foreign_key "seller_documents", "sellers", on_delete: :cascade
  add_foreign_key "seller_tiers", "sellers", on_delete: :cascade
  add_foreign_key "seller_tiers", "sellers", on_delete: :cascade
  add_foreign_key "seller_tiers", "tiers"
  add_foreign_key "sellers", "age_groups"
  add_foreign_key "sellers", "counties"
  add_foreign_key "sellers", "document_types"
  add_foreign_key "sellers", "sub_counties"
  add_foreign_key "sub_counties", "counties"
  add_foreign_key "tier_features", "tiers"
  add_foreign_key "tier_pricings", "tiers"
  add_foreign_key "wish_lists", "ads"
  add_foreign_key "wish_lists", "buyers", on_delete: :cascade
  add_foreign_key "wish_lists", "buyers", on_delete: :cascade
  add_foreign_key "wish_lists", "sellers", on_delete: :cascade
  add_foreign_key "wish_lists", "sellers", on_delete: :cascade
end
