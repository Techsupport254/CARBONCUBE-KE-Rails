# Carbon Backend — Comprehensive Codebase Research & File Inventory

> **Generated on:** October 29, 2026  
> **Workspace:** `/Users/user/Desktop/work/Carbon/backend`  
> **Total Files Cataloged:** 1,323 files  

---

## 1. Executive Summary & Architecture Overview

The Carbon backend is a high-performance **Ruby on Rails 7.1** API platform designed to power the Carbon / Loop commerce ecosystem in Kenya. It handles a multi-sided marketplace encompassing Buyers, Sellers, Field Sales Representatives, Internal Administrators, and Marketing teams.

### Core Technology Stack

- **Runtime & Framework:** Ruby (>= 3.4.0), Rails 7.1.x, Puma Application Server
- **Database & Query Layer:** PostgreSQL with `pg_trgm` (trigram similarity), `pg_search` (full-text search), composite indexes, and Active Record migrations (301 migrations)
- **Real-Time WebSockets:** ActionCable backed by Redis and AnyCable (`bin/anycable-go` binary) for real-time customer/merchant chat, live notifications, and presence detection
- **Background Processing:** Sidekiq & Sidekiq-cron with Redis connection pooling for asynchronous job processing, scheduled campaigns, and automated follow-up sequences
- **Email Pipeline:** Next-generation hybrid architecture using **React Email** (`@react-email/components` in TypeScript rendered with Bun/Vite) paired with standard ActionMailer and MJML templates
- **Messaging & WhatsApp:** WhatsApp Cloud API integration (`WhatsAppCloudService`, Twilio) for seller onboarding, catalog creation, transactional notifications, and marketing outreach
- **Payment & Financial Services:** Safaricom M-Pesa integration (C2B validation/confirmation and STK Push) alongside Apple In-App Purchase (IAP) validation
- **Authentication & Security:** JWT (JSON Web Tokens), BCrypt password hashing, Google OAuth2, Apple OAuth, WebAuthn / FIDO2 (Google Play Restore Credentials for zero-tap login), and Rack-Attack rate limiting
- **Observability & Analytics:** Sentry (error tracking), OpenTelemetry (distributed tracing), Google Analytics 4 (GA4 Measurement Protocol & Data API), Google Merchant Center API, and custom telemetry/click event tracking
- **Asset Storage & Processing:** Cloudinary (ActiveStorage integration), Cloudflare R2, MiniMagick, RQRCode (dynamic seller storefront QR standee and welcome graphics)

---

## 2. Directory Breakdown & Summary Statistics

| Directory | Total Files | Primary Languages / Formats | Key Responsibilities |
|---|:---:|---|---|
| **`app/`** | 577 | Ruby, TypeScript, JavaScript, ERB, MJML | Application core: controllers, models, services, jobs, mailers, serializers, views, and React email templates |
| **`config/`** | 42 | Ruby, YAML, Encrypted Credentials | Application configurations, initializers (24 files), environments, routing, Puma, Sidekiq, and schedules |
| **`db/`** | 307 | Ruby, JSON, CSV | Active Record schema, seeds, Kenyan geographical gazetteer, sales brands data, lead lists, and 301 migrations |
| **`lib/`** | 73 | Ruby, Rake, CJS | Core utilities, HTTP middlewares, 22 database/UTM diagnostic scripts, and 45 automation Rake tasks |
| **`scripts/`** | 111 | Ruby, Python, Swift, JSON | Product scrapers (GSM Arena, Apple, hardware, automotive), catalog generators, expansion datasets, and JSON outputs |
| **`spec/`** | 36 | Ruby (RSpec) | RSpec test suite covering factories, models, requests, jobs, and Google Merchant integration |
| **`test/`** | 85 | Ruby (Minitest), YAML | Rails Minitest suite covering controllers, fixtures (26 YAML files), models, mailer previews, and channels |
| **`public/`** | 28 | HTML, JS, PNG, JPG, ICO, TXT | Public static files, HTTP error pages, OAuth callbacks, cached seller profile images, and campaign banners |
| **`bin/`** | 7 | Shell, Ruby, Go Binary | Binstubs (`rails`, `bundle`, `setup`), AnyCable-Go compiled binary, and Render deployment scripts |
| **`docs/`** | 1 | Markdown | Email inventory and communication documentation |
| **Root (`/`)** | 48 | Ruby, Shell, JSON, TOML, Markdown, Config | Project configuration (`Gemfile`, `package.json`, `mise.toml`, `render.yaml`), RuboCop configs, benchmark & test utilities |
| **Runtime / Keep** | 8 | `.keep` files | Git directory placeholders in `log/`, `storage/`, `tmp/`, and `vendor/` |
| **`.github/`** | 1 | YAML | GitHub Actions continuous integration workflow |
| **TOTAL** | **1,323** | — | **Complete Carbon Backend Codebase** |

---

## 3. Subsystem Architecture & Functional Domains

```
                                  +-----------------------------+
                                  |     Clients & Frontends     |
                                  |  (Next.js Web, iOS, Android)|
                                  +--------------+--------------+
                                                 |
                                                 v
                                  +-----------------------------+
                                  |    Puma / Rack-Attack CORS  |
                                  +--------------+--------------+
                                                 |
                    +----------------------------+----------------------------+
                    |                            |                            |
                    v                            v                            v
          +-------------------+        +-------------------+        +-------------------+
          |  Buyer Endpoints  |        |  Seller Endpoints |        |  Sales & Admin    |
          |  (Browse, Search, |        |  (Inventory, Ads, |        |  (Moderation, KYC,|
          |   Offers, Reviews)|        |   Plans, Analytics|        |   Reports, Leads) |
          +---------+---------+        +---------+---------+        +---------+---------+
                    |                            |                            |
                    +----------------------------+----------------------------+
                                                 |
                                                 v
                                  +-----------------------------+
                                  |      Core Service Layer     |
                                  |  - AdSearchService          |
                                  |  - ContentModeration        |
                                  |  - WhatsAppCloudService     |
                                  |  - MpesaSTK / C2B Service   |
                                  |  - GoogleMerchantService    |
                                  +--------------+--------------+
                                                 |
                    +----------------------------+----------------------------+
                    |                            |                            |
                    v                            v                            v
          +-------------------+        +-------------------+        +-------------------+
          | PostgreSQL + TRGM |        |   Redis & Sidekiq |        | ActionCable / WS  |
          |  - 301 Migrations |        |  - 73 Async Jobs  |        |  - Conversations  |
          |  - PgSearch index |        |  - Cron Schedules |        |  - Notifications  |
          +-------------------+        +-------------------+        +-------------------+
```

### 3.1 Role-Based API Separation
Controllers and serializers are strictly segmented according to user capabilities:
- **`app/controllers/buyer/`**: Product browsing, smart search, offers, wishlist, and cart interactions.
- **`app/controllers/seller/`**: Storefront management, ad lifecycles, analytics, tier billing, branches, and verification document submission.
- **`app/controllers/sales/`**: CRM tools, field sales tracking, prospect follow-ups, daily reports, call center operations, and quarterly target management.
- **`app/controllers/admin/`**: Content moderation, fraud review, KYC seller verification, metric dashboards, and communications blasting.
- **`app/controllers/marketing/`**: Brand categories, featured placements, and campaign telemetry.

### 3.2 Messaging, WebSockets & Real-Time Sync
Real-time customer engagement is powered by ActionCable and AnyCable:
- **`app/channels/conversations_channel.rb`**: Real-time buyer-seller chat with delivery and read receipts (`ProcessReadReceiptJob`).
- **`app/channels/notifications_channel.rb`**: Push notifications and in-app updates.
- **`app/channels/presence_channel.rb`**: Real-time user online/offline status tracking.
- **`app/services/unread_message_reminder_service.rb`**: Intelligent drip reminder engine respecting East Africa Time (EAT) quiet hours (10:00 PM – 7:00 AM).

### 3.3 Email Architecture (React Email + ActionMailer)
Rather than legacy monolithic HTML ERB templates, the platform leverages TypeScript React Email components compiled via Vite/Bun:
- **Components (`app/javascript/emails/_components/`)**: `email_layout.tsx`, `header.tsx`, `footer.tsx`, `button.tsx`, `info_card.tsx`, `code_block.tsx`, `divider.tsx`, `icon.tsx`.
- **Templates (`app/javascript/emails/`)**: 56 rich transactional and marketing templates spanning seller onboarding, document verification, weekly performance checkpoints, review alerts, and seasonal campaigns.

### 3.4 Content Moderation & Risk Engine
Integrated multi-tier safety architecture evaluating every ad listing:
- **`CompositeRiskEngine`**: Integrates text and visual risk scores.
- **`VisionSafetyService`**: Detects unsafe imagery or policy violations.
- **`NlpSafetyService`**: Scans titles and descriptions for scam keywords and prohibited items.
- **`HeuristicRuleEvaluator`**: Validates pricing anomalies, duplicate listings, and blacklisted contact info.
- **`SellerTrustScorer`**: Calculates dynamic merchant reputation scores based on verification status and dispute history.

---

## 4. Complete File Inventory

### 4.1 Root Directory Configuration & Scripts (48 files)

| File Path | Description |
|---|---|
| `.dockerignore` | Files excluded from Docker container builds |
| `.env.example` | Template of required environment variables for development and production |
| `.gitattributes` | Git attribute settings for line endings and binary diffing |
| `.gitignore` | Ignored files (logs, dumps, keys, bundle, node_modules) |
| `.rubocop.yml` | RuboCop static analysis configuration and active plugins |
| `.rubocop_todo.yml` | RuboCop legacy offense suppression rules |
| `.ruby-version` | Specifies targeted Ruby version (3.4.x) |
| `AGENTS.md` | Developer and AI agent guidelines for backend maintenance and linting |
| `Gemfile` | Ruby gem dependency specifications |
| `Gemfile.lock` | Exact locked dependency versions for Bundler |
| `README.md` | Core backend setup, database preparation, and developer documentation |
| `Rakefile` | Primary Rake task loading definition for Rails |
| `WHATSAPP_PRODUCT_CREATION_README.md` | Documentation for WhatsApp automated product ingestion flows |
| `benchmark_whatsapp.rb` | Performance benchmarking script for WhatsApp webhook processing |
| `bun.lock` | Bun package manager lockfile for email JavaScript assets |
| `campaign_output.log` | Execution log output from campaign runs |
| `config.ru` | Rack server entrypoint for Puma |
| `debug_product_creation.rb` | Diagnostic utility for testing AI-assisted ad creation |
| `deploy-vps.sh` | Shell script for automated VPS deployment |
| `dump_and_restore_from_production.sh` | Production database dump and local restoration script |
| `dump_and_restore_redis_from_production.sh` | Production Redis snapshot sync script |
| `dump_to_banana.sh` | Database backup and export automation script |
| `generate_valentines_csv.sh` | Utility script generating CSV data for Valentine's campaign |
| `mise.toml` | Mise-en-place runtime version configuration (Ruby, Bun) |
| `package.json` | Node/Bun configuration for React Email and build scripts |
| `query_sales.rb` | Direct database query utility for sales performance reporting |
| `railpack.json` | Railpack build and container deployment configuration |
| `rails.log` | Local development runtime log |
| `render.yaml` | Render cloud deployment blueprint for web service and Redis |
| `simple_benchmark.rb` | Database query and API throughput benchmarking tool |
| `test_actioncable.rb` | ActionCable WebSocket connection and subscription verification script |
| `test_actual_video_send.sh` | WhatsApp video message dispatch test script |
| `test_api.sh` | Comprehensive cURL test suite for core backend API endpoints |
| `test_apple_laptop.rb` | Specification parsing test for Apple laptop catalog ingestion |
| `test_apple_macbook.rb` | Test script for MacBook ad generation and categorization |
| `test_buyers_compare_email_preview.html` | Generated preview HTML for "Buyers Compare" email campaign |
| `test_condition_selection.rb` | Test suite for product condition evaluation algorithms |
| `test_email_preview.html` | Local preview artifact for React email rendering |
| `test_improvements.rb` | Evaluation script for ad enrichment and metadata algorithms |
| `test_laptop_images.rb` | Image attachment and thumbnail generation test for laptops |
| `test_media_send.sh` | WhatsApp media upload and webhook test script |
| `test_whatsapp_images.rb` | WhatsApp inbound image processing verification |
| `test_whatsapp_images_fixed.rb` | Refactored image upload and attachment test for WhatsApp |
| `test_whatsapp_product_creation.sh` | End-to-end integration test for creating ads over WhatsApp |
| `tmp_check_users.rb` | Database verification script for auditing active user roles |
| `tsconfig.json` | TypeScript configuration for React Email components |
| `vite.config.ts` | Vite bundler configuration for compiling React email templates |
| `.DS_Store` | macOS filesystem directory metadata |

---

### 4.2 Application Controllers (`app/controllers/`) (165 files)

#### Base & Global Controllers
- `application_controller.rb`: Root controller handling global exception handling, JWT extraction, and current actor resolution
- `authentication_controller.rb`: Multi-role login, token generation, OAuth callbacks, and account reactivation
- `health_controller.rb`: Health endpoints (`/health`, `/health/database`, `/health/redis`, `/health/websocket`, `/health/overall`)
- `home_controller.rb`: Root API welcome and status endpoint
- `contact_controller.rb`: Public contact inquiry submission and automated acknowledgments
- `data_deletion_controller.rb`: GDPR/privacy compliant user data deletion requests
- `password_resets_controller.rb`: Forgot-password OTP request and password modification
- `email_otps_controller.rb`: Email verification OTP issuance and validation
- `device_tokens_controller.rb`: Mobile device push token registration (FCM/APNS)
- `device_fingerprints_controller.rb`: Browser/device fingerprinting for fraud prevention
- `internal_user_exclusions_controller.rb`: Exclusion registry for internal team analytics filtering
- `restore_credentials_controller.rb`: WebAuthn credential restoration for seamless login
- `profile_pictures_controller.rb`: Cached profile avatar serving and proxying
- `proxy_controller.rb`: Image and external asset proxying to bypass CORS/mixed-content
- `sitemap_controller.rb`: Dynamic XML sitemap generator for SEO indexing
- `webhooks_controller.rb`: External incoming webhook processor (Stripe, Cloudinary, Twilio)
- `whatsapp_controller.rb`: Inbound WhatsApp Cloud API webhook handler
- `mpesa_controller.rb`: Safaricom M-Pesa C2B validation, confirmation, and STK status callbacks
- `payments_controller.rb`: Payment status inquiries and checkout initialization
- `notifications_controller.rb`: User notification feed and mark-as-read endpoints
- `visitor_analytics_controller.rb`: Anonymous storefront visitor tracking
- `source_tracking_controller.rb`: UTM and traffic source attribution telemetry
- `subcategory_clicks_controller.rb`: Subcategory click tracking for recommendation scoring
- `automation_controller.rb`: Webhook triggers for scheduled maintenance jobs
- `app_store_review_prompt_controller.rb`: In-app review prompt eligibility checks

#### Marketplace Resource Controllers
- `ads_controller.rb`: Public ad listings, details, and filtering
- `categories_controller.rb`: Category hierarchy and navigation
- `counties_controller.rb`: Kenyan county listings
- `document_types_controller.rb`: Required seller KYC document types
- `educations_controller.rb`: User education level metadata
- `employments_controller.rb`: User employment status metadata
- `incomes_controller.rb`: User income bracket metadata
- `sectors_controller.rb`: Business sector classifications
- `age_groups_controller.rb`: Demographic age group metadata
- `banners_controller.rb`: Homepage promotional banners
- `best_sellers_controller.rb`: Top-selling products and cached rankings
- `brand_kenya_controller.rb`: "Made in Kenya" brand initiative directory
- `conversations_controller.rb`: User conversation index and message thread access
- `messages_controller.rb`: Chat message sending and retrieval
- `reviews_controller.rb`: Public product and merchant reviews
- `shops_controller.rb`: Public seller storefront profiles and item lists
- `tiers_controller.rb`: Seller subscription plans and pricing
- `feeds_controller.rb`: RSS / JSON syndication feeds
- `partners_controller.rb`: Strategic partner listings and verified badges
- `partner_invites_controller.rb`: Partner invite token resolution and acceptance
- `issues_controller.rb`: Bug reports and support ticket submission
- `ad_searches_controller.rb`: Search query analytics and popular keywords
- `click_events_controller.rb`: Ad click and view event tracking
- `email_controller.rb`: Inbound email webhook and parsing
- `geocoding_controller.rb`: Forward and reverse geocoding endpoints

#### Buyer Portal Namespace (`app/controllers/buyer/`)
- `buyer/ads_controller.rb`: Buyer-specific ad viewing and recommendations
- `buyer/buyers_controller.rb`: Buyer profile management
- `buyer/cart_items_controller.rb`: Shopping cart management
- `buyer/categories_controller.rb`: Category browsing tailored to buyers
- `buyer/conversations_controller.rb`: Buyer chat conversations with merchants
- `buyer/messages_controller.rb`: Message exchange within buyer threads
- `buyer/offers_controller.rb`: Price offer negotiation on listings
- `buyer/profiles_controller.rb`: Buyer personal details and delivery addresses
- `buyer/promotions_controller.rb`: Discount codes and promotions for buyers
- `buyer/review_prompts_controller.rb`: Prompts asking buyers to review recent transactions
- `buyer/reviews_controller.rb`: Review submission and editing by buyers
- `buyer/subcategories_controller.rb`: Buyer subcategory discovery
- `buyer/wish_lists_controller.rb`: Saved items and wishlist management

#### Seller Portal Namespace (`app/controllers/seller/`)
- `seller/ads_controller.rb`: Seller ad inventory management (CRUD, status, pricing)
- `seller/analytics_controller.rb`: Merchant sales analytics, view counts, and market intelligence
- `seller/branches_controller.rb`: Multi-location store branches
- `seller/buyer_details_controller.rb`: Customer contact reveal for verified leads
- `seller/catalogs_controller.rb`: Bulk catalog upload and processing
- `seller/categories_controller.rb`: Category assignment for seller inventory
- `seller/conversations_controller.rb`: Merchant conversation inbox
- `seller/dashboard_controller.rb`: Seller performance KPI dashboard
- `seller/google_business_profiles_controller.rb`: Google Business Profile integration
- `seller/messages_controller.rb`: Merchant replies and message attachments
- `seller/offers_controller.rb`: Reviewing, accepting, or declining buyer offers
- `seller/partner_contacts_controller.rb`: Partner brand contact directory
- `seller/partner_distributors_controller.rb`: Authorized distributor associations
- `seller/partner_profiles_controller.rb`: Brand partner profile configuration
- `seller/pricing_templates_controller.rb`: Saved pricing templates for fast ad creation
- `seller/profiles_controller.rb`: Merchant profile, business permits, and KYC data
- `seller/review_requests_controller.rb`: Requesting manual review approvals from admins
- `seller/reviews_controller.rb`: Merchant replies to customer reviews
- `seller/seller_documents_controller.rb`: Business registration and ID document uploads
- `seller/seller_tiers_controller.rb`: Subscription plan selection and upgrade checkout
- `seller/sellers_controller.rb`: Merchant account settings
- `seller/seo_analyses_controller.rb`: On-page SEO recommendations for product listings
- `seller/subcategories_controller.rb`: Subcategory management for merchant catalogs
- `seller/tiers_controller.rb`: Tier comparison and benefits viewing

#### Sales Team Namespace (`app/controllers/sales/`)
- `sales/ad_searches_controller.rb`: Search term trends monitored by sales reps
- `sales/ads_controller.rb`: Sales rep ad review and assistance
- `sales/analytics_controller.rb`: Field sales performance metrics
- `sales/app_installs_controller.rb`: Mobile app installation attribution
- `sales/brands_controller.rb`: Brand acquisition pipeline
- `sales/buyers_controller.rb`: Buyer lead insights for sales reps
- `sales/call_center_controller.rb`: Call queue, call logs, and phone outreach console
- `sales/catalogs_controller.rb`: Merchant catalog ingestion on behalf of sellers
- `sales/click_events_controller.rb`: Click conversion tracking for field campaigns
- `sales/conversations_controller.rb`: Sales rep assistance in merchant chats
- `sales/daily_reports_controller.rb`: Daily sales activity reporting
- `sales/field_locations_controller.rb`: GPS check-ins for field agents
- `sales/google_analytics_controller.rb`: GA4 reports for sales management
- `sales/holidays_controller.rb`: Public holidays affecting sales schedules
- `sales/offers_controller.rb`: Offer arbitration by sales agents
- `sales/online_controller.rb`: Online presence tracking of sales personnel
- `sales/partner_contacts_controller.rb`: Lead management for brand representatives
- `sales/partner_distributors_controller.rb`: Onboarding authorized brand distributors
- `sales/partner_updates_controller.rb`: Broadcast updates to partner networks
- `sales/partners_controller.rb`: Strategic partner account management
- `sales/profiles_controller.rb`: Sales representative profile management
- `sales/quarterly_targets_controller.rb`: Sales quotas and goal tracking
- `sales/reports_controller.rb`: Aggregate weekly and monthly sales reporting
- `sales/reviews_controller.rb`: Review moderation for sales onboarded accounts
- `sales/seller_follow_ups_controller.rb`: Scheduled calls and visits to merchants
- `sales/seller_rankings_controller.rb`: Merchant tiering and priority scorecards
- `sales/seller_verifications_controller.rb`: Field verification of merchant physical locations
- `sales/sellers_controller.rb`: Merchant accounts managed by sales agents
- `sales/wish_lists_controller.rb`: Customer demand analysis via wishlist trends

#### Admin Management Namespace (`app/controllers/admin/`)
- `admin/abouts_controller.rb`: About Us content management
- `admin/ad_searches_controller.rb`: Global search analytics and term suppression
- `admin/admins_controller.rb`: Internal administrator user management
- `admin/ads_controller.rb`: Platform-wide ad moderation and takedowns
- `admin/analytics_controller.rb`: Platform aggregate metrics and revenue
- `admin/banners_controller.rb`: Marketing banner scheduling and uploading
- `admin/buyer/profiles_controller.rb`: Buyer account inspection and moderation
- `admin/buyers_controller.rb`: Buyer user directory
- `admin/carbon_codes_controller.rb`: Merchant physical store verification codes
- `admin/categories_controller.rb`: Master category taxonomy management
- `admin/click_events_controller.rb`: Fraudulent click audit and IP filtering
- `admin/cms_pages_controller.rb`: CMS pages (Terms, Privacy, FAQs)
- `admin/conversations_controller.rb`: Chat thread auditing for policy violations
- `admin/daily_reports_controller.rb`: Executive overview of daily sales reports
- `admin/faqs_controller.rb`: FAQ creation and categorisation
- `admin/field_locations_controller.rb`: Territory and field sales location audits
- `admin/google_merchant_controller.rb`: Google Shopping feed status and resync
- `admin/holidays_controller.rb`: Platform operating calendars
- `admin/internal_user_exclusions_controller.rb`: Analytics exclusion list management
- `admin/issues_controller.rb`: Platform bug reports, ticket assignment, and resolutions
- `admin/messages_controller.rb`: Administrative message auditing
- `admin/monitoring_controller.rb`: System errors, background job status, and metrics
- `admin/offers_controller.rb`: Offer dispute resolution
- `admin/profiles_controller.rb`: Admin user profile settings
- `admin/promotions_controller.rb`: Site-wide promotional campaigns
- `admin/quarterly_targets_controller.rb`: Company KPI target definitions
- `admin/review_requests_controller.rb`: Review approval queue
- `admin/reviews_controller.rb`: Flagged review moderation
- `admin/seller/ads_controller.rb`: Inspection of ads for a specific seller
- `admin/seller/analytics_controller.rb`: Specific merchant performance audits
- `admin/seller/reviews_controller.rb`: Specific merchant review histories
- `admin/seller_communications_controller.rb`: Mass communication broadcasts to sellers
- `admin/sellers_controller.rb`: Seller KYC approvals, bans, and tier overrides
- `admin/subcategories_controller.rb`: Subcategory creation and taxonomies
- `admin/tiers_controller.rb`: Subscription plan definition and pricing adjustments
- `admin/users_controller.rb`: Unified user account management

#### Marketing Namespace (`app/controllers/marketing/`)
- `marketing/categories_controller.rb`: Featured promotional categories
- `marketing/profiles_controller.rb`: Marketing manager profile settings
- `marketing/subcategories_controller.rb`: Subcategory campaigns and SEO landing settings

#### API v1 Namespace (`app/controllers/api/` & `api/v1/`)
- `api/mobile_releases_controller.rb`: App version enforcement and update checks
- `api/v1/monitoring_controller.rb`: Remote uptime ping and monitoring ingest
- `api/v1/seller_locations_controller.rb`: Mobile geocoding and location updates

#### Controller Concerns (`app/controllers/concerns/`)
- `activity_tracking.rb`: Logs user timestamps, IP addresses, and user agent data
- `exception_handler.rb`: Rescues ActiveRecord and JWT exceptions with clean JSON responses
- `partner_logo_uploadable.rb`: Common Cloudinary image attachment logic for partners
- `sales_or_admin_authenticatable.rb`: Dual-role authorization guard for staff endpoints
- `.keep`: Git directory preservation

---

### 4.3 Models (`app/models/`) (93 files)

#### Marketplace & Listings
- `ad.rb`: Core product listing model with validations, full-text search, and scopes
- `ad_stat.rb`: Aggregated view, click, and contact metrics per ad
- `category.rb`: Primary taxonomy node
- `subcategory.rb`: Granular product sub-classification
- `categories_seller.rb`: Join table for merchant category authorizations
- `sales_brand.rb`: Curated brand model with verification badges
- `sales_brand_activity.rb`: Audit history for brand updates
- `best_sellers_cache.rb`: Materialized cache of highest performing items
- `offer.rb`: Price negotiation offer made by a buyer to a seller
- `offer_ad.rb`: Product relationship within an offer
- `cart_item.rb`: Shopping cart line item
- `wish_list.rb`: Saved items for buyer accounts
- `review.rb`: Buyer review with star ratings and seller reply
- `review_request.rb`: Merchant request for customer review submission
- `review_prompt.rb`: System-triggered review nudges
- `banner.rb`: Promotional banners displayed on mobile and web
- `promotion.rb`: Discounts, coupon codes, and campaign parameters

#### Users & Authentication
- `buyer.rb`: Registered buyer account with contact and profile details
- `seller.rb`: Merchant account with KYC, physical address, tier, and shop settings
- `sales_user.rb`: Field sales representative account
- `admin.rb`: Administrator account with role-based access
- `marketing_user.rb`: Marketing team account
- `application_record.rb`: Base Active Record class
- `password_otp.rb`: Password reset One-Time Passwords
- `email_otp.rb`: Email verification One-Time Passwords
- `restore_credential.rb`: FIDO2 / WebAuthn passkey credentials
- `device_token.rb`: Push notification tokens (iOS APNS / Android FCM)
- `device_fingerprint.rb`: Browser fingerprints for device tracking and anti-fraud
- `internal_user_exclusion.rb`: IP and device exclusions for internal staff

#### Communications & Chat
- `conversation.rb`: Chat thread linking buyers and sellers
- `conversation_read_mark.rb`: Timestamp tracking for read receipts
- `message.rb`: Individual chat message with status, text, and attachments
- `notification.rb`: Polymorphic in-app user notifications
- `whatsapp_message_log.rb`: Transactional log of WhatsApp messages sent/received
- `whatsapp_product_session.rb`: Multi-step conversation state for WhatsApp ad creation
- `email_communication_log.rb`: Delivery record of automated marketing/transactional emails

#### Seller Plans & Operations
- `tier.rb`: Merchant subscription tier definition (Free, Basic, Premium)
- `tier_feature.rb`: Feature entitlements belonging to a subscription tier
- `tier_pricing.rb`: Billing options (monthly, quarterly, annual)
- `seller_tier.rb`: Active subscription association for a merchant
- `seller_document.rb`: Uploaded business permits and national identity documents
- `document_type.rb`: Registry of acceptable KYC document types
- `branch.rb`: Physical branch location for a merchant
- `carbon_code.rb`: Physical QR verification code assigned to physical stores
- `seller_carbon_code_assignment.rb`: Merchant assignment of physical verification codes
- `seller_pricing_template.rb`: Reusable pricing structures for merchants
- `seller_verification.rb`: Field agent verification record of a merchant premises
- `seller_follow_up.rb`: CRM record for salesperson check-ins with merchants

#### Strategic Partnerships
- `partner.rb`: Enterprise brand partner entity
- `partner_contact.rb`: Contact person for a brand partner
- `partner_distributor.rb`: Link between brand partners and authorized local sellers
- `partner_invite.rb`: Invitation token for merchants to join a brand network
- `partner_update.rb`: Informational broadcast from a brand partner
- `partner_activity.rb`: Audit log of partner administrative actions

#### Sales & Field Operations
- `sales_daily_report.rb`: Daily activity log filed by field sales reps
- `sales_holiday.rb`: Official holiday calendar for sales target calculations
- `quarterly_target.rb`: Sales revenue and acquisition targets
- `sales_user_field_location.rb`: GPS tracking coordinates of field agents
- `outreach_prospect.rb`: External business lead identified for platform onboarding
- `call_queue.rb`: Priority queue for outbound sales calls
- `call_record.rb`: Call disposition and notes from call center agents

#### Analytics & Telemetry
- `analytic.rb`: Comprehensive visit and interaction event model
- `click_event.rb`: Granular ad click tracking with referrer attribution
- `ad_search.rb`: Search query log
- `search_analytic.rb`: Aggregated search metrics and click-through analysis
- `search_synonym.rb`: Synonym mapping for fuzzy search expansions
- `visitor.rb`: Unique visitor tracking across sessions
- `app_install_nudge_campaign.rb`: Tracking for mobile app download prompts
- `app_store_review_prompt.rb`: History of App Store review prompts shown

#### Payments & Compliance
- `payment.rb`: Generic payment record
- `payment_transaction.rb`: M-Pesa STK Push / C2B transaction state and receipt
- `data_deletion_request.rb`: GDPR deletion request lifecycle
- `issue.rb`: Issue/bug report submitted by users
- `issue_comment.rb`: Collaboration notes on support issues
- `comment_vote.rb`: Upvotes/downvotes on community comments
- `issue_attachment.rb`: Screenshots and logs attached to support issues

#### Monitoring & System
- `monitoring_error.rb`: Logged system exception for administrative triage
- `monitoring_metric.rb`: Performance metric record (response times, queue lengths)
- `mobile_release.rb`: Mobile app version registry with mandatory update flags
- `cms_page.rb`: Static CMS content
- `about.rb`: Company about section data
- `faq.rb`: Frequently Asked Questions entry
- `county.rb`: Kenyan administrative county
- `sub_county.rb`: Sub-county geographical unit
- `income.rb`: Income range definition
- `education.rb`: Education level classification
- `employment.rb`: Employment status classification
- `sector.rb`: Industry sector classification
- `age_group.rb`: Age bracket classification
- `vehicle_type.rb`: Vehicle category classification

#### Model Concerns (`app/models/concerns/`)
- `actor_attribution.rb`: Reusable concern linking records to the acting user or admin
- `.keep`: Git directory preservation

---

### 4.4 Services (`app/services/`) (73 files)

#### Search, Catalog & Discovery
- `ad_search_service.rb`: Main search execution engine combining pg_search and rank weighting
- `catalog_search_expansion_service.rb`: Expands search queries using synonyms and related catalog terms
- `search_query_normalizer.rb`: Cleans, strips stopwords, and normalizes queries
- `search_synonym_expander.rb`: Replaces regional terminology with canonical catalog keys
- `search_popularity_boost.rb`: Dynamically scores listings based on recent impressions and inquiries
- `search_redis_service.rb`: Caches popular searches and autocomplete suggestions in Redis
- `similar_products_service.rb`: Algorithmic recommendation of comparable products
- `optimized_ads_service.rb`: Fast-path queries for high-traffic listing pages
- `device_catalog_service.rb`: Tech specs lookup for phones, laptops, and electronics
- `gsm_arena_service.rb`: GSM Arena specifications integration for mobile devices

#### AI & Content Moderation Pipeline
- `content_moderation/composite_risk_engine.rb`: Orchestrates risk evaluation across vision, text, and heuristics
- `content_moderation/heuristic_rule_evaluator.rb`: Fast deterministic rules (bad words, price limits, phone leaks)
- `content_moderation/nlp_safety_service.rb`: LLM-powered natural language safety and policy compliance
- `content_moderation/vision_safety_service.rb`: Image analysis for inappropriate or watermarked photos
- `content_moderation/seller_trust_scorer.rb`: Historical trust and risk scoring for merchants
- `groq_ai_service.rb`: Fast LLM inference client (Groq / Llama) for content analysis
- `image_analysis_service.rb`: Image quality, resolution, and feature extraction
- `whatsapp_ai_prefill_service.rb`: Extracts product title, price, and attributes from casual WhatsApp text
- `sales_field_report_ai_service.rb`: AI summarization of daily field sales reports

#### Messaging & Real-Time Sync
- `whats_app_cloud_service.rb`: Direct integration with Meta's WhatsApp Cloud API
- `whatsapp_product_creation_service.rb`: Interactive chatbot flow allowing sellers to post ads via WhatsApp
- `push_notification_service.rb`: Unified push dispatcher for iOS (APNs) and Android (Firebase FCM)
- `websocket_service.rb`: Broadcast helper wrapping ActionCable streams
- `websocket_message_validator.rb`: Security and schema validation for incoming WebSocket frames
- `unread_message_reminder_service.rb`: Automated reminder sequence for unanswered customer inquiries

#### Payments & Billing
- `mpesa_stk_service.rb`: Initiates Safaricom Daraja STK Push requests to customer mobile devices
- `mpesa_c2b_service.rb`: Registers URLs and handles C2B paybill confirmations
- `payment_verification_service.rb`: Reconciles M-Pesa receipts against pending subscriptions
- `iap_validation_service.rb`: Validates Apple App Store In-App Purchase receipts

#### Authentication & Security
- `jwt_service.rb`: Encodes and decodes JSON Web Tokens with configurable expiration
- `token_validation_service.rb`: Validates bearer tokens and handles revocatons
- `authorize_api_request.rb`: Base request authorization service
- `buyer_authorize_api_request.rb`: Guard ensuring the request actor is an authenticated buyer
- `seller_authorize_api_request.rb`: Guard ensuring the request actor is an active merchant
- `admin_authorize_api_request.rb`: Guard ensuring the request actor has administrative rights
- `google_oauth_service.rb`: Exchanges Google OAuth codes for profile data
- `apple_auth_service.rb`: Decodes Apple identity tokens and verifies signatures
- `oauth_account_linking_service.rb`: Merges OAuth credentials into existing accounts

#### SEO, Feeds & External Integrations
- `google_merchant_service.rb`: Syncs active ads to Google Merchant Center for Google Shopping
- `google_merchant_text_sanitizer.rb`: Cleans descriptions to meet Google Shopping feed policies
- `google_indexing_service.rb`: Pings Google Indexing API when new products are published
- `index_now_service.rb`: Pings Bing/IndexNow search engines on content creation
- `google_business_profile_service.rb`: Manages Google Business Profile locations and sync
- `google_place_review_service.rb`: Ingests and displays Google Maps reviews on merchant stores
- `seo_scraper_service.rb`: Audits meta tags, headings, and schema markup of product pages

#### Seller Growth & Partnerships
- `brand_kenya_outreach.rb`: Automation targeting local Kenyan manufacturers
- `organic_quality_coach_service.rb`: Generates actionable tips to help sellers improve ad quality
- `organic_featured_service.rb`: Ranks and selects high-quality organic listings for homepage spotlight
- `seller_ranking_service.rb`: Computes composite seller ranking for category placement
- `seller_category_placement_service.rb`: Optimizes merchant listing positions inside category trees
- `partner_presenter.rb`: Formats partner profiles and branding assets for UI consumption
- `partner_benefits.rb`: Resolves seller perks associated with partner certifications
- `partner_invite_copy.rb`: Localized copywriting for partner email and WhatsApp invitations
- `partner_invite_issuer.rb`: Generates single-use invite tokens for brand networks
- `welcome_image_generator_service.rb`: Creates personalized onboarding banner images using MiniMagick
- `seller_qr_standee_generator_service.rb`: Generates high-resolution printable QR standees for physical shops
- `offers_service.rb`: Manages price counter-offers and expiration logic

#### Telemetry, Geolocation & Infrastructure
- `click_events_analytics_service.rb`: Aggregates ad engagement metrics and conversion funnels
- `guest_click_association_service.rb`: Attributes anonymous click history to newly registered accounts
- `source_tracking_service.rb`: Parses UTM parameters and referral headers for attribution
- `visitor_tracking_service.rb`: Manages cookie/fingerprint visitor session lifetimes
- `google_analytics_service.rb`: Server-side GA4 event logging via Measurement Protocol
- `monitoring_service.rb`: Collects queue depths, database pool states, and memory metrics
- `performance_monitor.rb`: Benchmarks endpoint execution times and database query counts
- `upload_telemetry_redis_service.rb`: Tracks image upload speeds and failures in Redis
- `field_location_redis_service.rb`: Caches real-time GPS locations of field sales staff
- `call_queue_service.rb`: Selects and assigns prospect phone numbers to available sales agents
- `geocode_all_sellers_service.rb`: Coordinates batch geocoding of seller addresses
- `kenya_gazetteer_service.rb`: Normalizes Kenyan estate names, towns, and landmarks
- `cloudflare_r2_service.rb`: Direct-to-cloud upload helper for Cloudflare R2 object storage
- `profile_picture_cache_service.rb`: Locally caches and optimizes remote profile avatars
- `utm_url_helper.rb`: Utility generating standardized UTM parameters for shared links

---

### 4.5 Background Jobs (`app/jobs/`) (73 files)

#### Communications & Campaign Dispatchers
- `send_seller_communication_job.rb`: Primary dispatcher sending segmented bulk communications to sellers
- `send_bulk_seller_communication_job.rb`: Batched communication dispatcher for high-volume outreach
- `seller_communication_mail_delivery_job.rb`: Asynchronous delivery worker for communication emails
- `black_friday_2026_campaign_job.rb`: Dispatches Black Friday promotional deals and alerts
- `send_prospect_email_job.rb`: Sends cold outreach emails to prospective merchant leads
- `prospect_outreach_batch_job.rb`: Batches prospect leads and enqueues individual send workers
- `send_whatsapp_updates_invite_job.rb`: Invites sellers to join the Carbon WhatsApp broadcast channel
- `send_whatsapp_template_job.rb`: Dispatches pre-approved Meta WhatsApp templates
- `send_bulk_whatsapp_template_job.rb`: Bulk sender for template-based WhatsApp broadcasts
- `send_accurate_listings_whatsapp_job.rb`: WhatsApp educational guide on creating accurate listings
- `send_accurate_listings_optimized_job.rb`: Optimized variant targeting active merchants
- `send_shop_identity_whats_app_job.rb`: WhatsApp nudge urging merchants to complete their store profile
- `send_shop_identity_optimized_job.rb`: Optimized dispatch for shop identity completion
- `send_product_details_what_sapp_job.rb`: Tips on writing compelling product specifications via WhatsApp
- `send_product_details_optimized_job.rb`: Optimized specs advice dispatcher
- `send_product_details_to_all_sellers_job.rb`: Global broadcast educating merchants on ad enrichment
- `send_listing_update_optimized_job.rb`: Nudge prompting sellers to refresh stale listings
- `send_new_features_campaign_job.rb`: Announcement email regarding new platform capabilities
- `send_share_shop_feature_optimized_job.rb`: Educational email highlighting storefront sharing tools
- `send_user_buying_safety_campaign_job.rb`: Buyer-facing safety and anti-fraud advisory campaign
- `send_verify_before_buying_campaign_job.rb`: Buyer campaign emphasizing verified merchant badges
- `send_bulk_buying_safety_campaign_job.rb`: Batched variant of the buyer safety campaign
- `send_single_seller_marketing_job.rb`: Custom targeted marketing email to an individual merchant
- `send_seller_marketing_broadcast_job.rb`: Broadcast campaign targeting specific seller tiers
- `send_profile_completion_campaign_job.rb`: Campaign reminding incomplete accounts to finish onboarding
- `send_buyers_compare_campaign_job.rb`: Seller email illustrating how buyers evaluate competitor prices

#### Onboarding & Reminder Sequences
- `send_catalog_upload_request_job.rb`: Prompts new sellers to upload their product catalog
- `send_catalog_upload_reminder_job.rb`: Follow-up reminder for pending catalog uploads
- `send_catalog_upload_to_new_sellers_job.rb`: Automated trigger for sellers registered in the last 24h
- `send_catalog_upload_reminder_to_new_sellers_job.rb`: Secondary follow-up for new registrations
- `send_catalog_upload_broadcast_job.rb`: Broad announcement regarding new catalog import tools
- `send_catalog_upload_reminder_broadcast_job.rb`: Scheduled reminder broadcast for catalog completion
- `send_app_install_nudge_job.rb`: Nudges web users to install the native mobile app
- `send_phone_update_reminder_job.rb`: Prompts users with missing phone numbers to add them for WhatsApp alerts
- `send_review_prompts_job.rb`: Scheduled job sending review invitations to recent buyers
- `unread_message_reminder_job.rb`: Sends email/WhatsApp alerts for unread chat messages
- `schedule_app_store_review_prompts_job.rb`: Schedules in-app store review dialogs for active users
- `send_seller_qr_job.rb`: Generates and delivers personalized store QR standee graphics to merchants

#### Partner & Brand Automations
- `partner_invite_job.rb`: Dispatches brand partner invitations to authorized merchants
- `partner_invite_reminder_job.rb`: Sends reminder emails for unopened partner invites
- `partner_joined_notification_job.rb`: Notifies brand managers when an authorized dealer registers
- `partner_update_fanout_job.rb`: Broadcasts price or catalog changes from brands down to their dealer network
- `partner_price_drop_job.rb`: Alerts customers and dealers when a partner slashes retail prices
- `brand_kenya_onboarded_notify_job.rb`: Internal alert when a "Made in Kenya" brand completes verification

#### KYC & Verification
- `seller_verification_notification_job.rb`: Alerts merchants when their verification documents are reviewed
- `document_compliance_check_job.rb`: Daily scan identifying documents expiring within 30 days
- `send_document_compliance_reminder_job.rb`: Sends renewal reminders for expiring business permits
- `send_compliance_reminder_sequence_job.rb`: Multi-stage compliance sequence before account suspension

#### Data Sync & Catalog Maintenance
- `google_merchant_sync_job.rb`: Submits active ad listings to Google Merchant Center Shopping feed
- `sync_google_reviews_scheduler_job.rb`: Cron worker scheduling Google Business review syncs
- `sync_google_reviews_for_seller_job.rb`: Fetches Google Maps reviews for an individual merchant
- `geocode_sellers_job.rb`: Geocodes merchant street addresses into latitude/longitude pairs
- `sync_field_locations_job.rb`: Syncs salesperson GPS logs into permanent reporting tables
- `sync_seller_category_placement_job.rb`: Recalculates merchant category rankings based on sales
- `refresh_ad_stats_job.rb`: Aggregates impression and click logs into `ad_stats`
- `sync_search_analytics_job.rb`: Consolidates popular search queries into analytics cache
- `backfill_user_agent_details_job.rb`: Enriches historical session logs with device/browser metadata
- `search_index_ping_job.rb`: Pings search engine indexing APIs when listings change
- `auto_enrich_ad_quality_job.rb`: Runs automated quality scoring on newly published ads
- `evaluate_organic_featured_ads_job.rb`: Daily audit promoting top-tier organic listings to homepage

#### Operations, Moderation & Real-Time
- `moderate_ad_job.rb`: Runs automated risk evaluation (`CompositeRiskEngine`) on new ads
- `process_websocket_message_job.rb`: Asynchronous message processing pipeline for ActionCable
- `message_delivery_job.rb`: Enforces message delivery guarantees and webhook broadcasts
- `process_read_receipt_job.rb`: Updates message read receipts and updates unread badge counts
- `update_unread_counts_job.rb`: Recalculates unread badge counters across all active threads
- `review_push_notification_job.rb`: Sends instant mobile push alerts when a review is received
- `broadcast_app_update_job.rb`: Broadcasts mandatory version update warnings over WebSockets
- `call_persist_job.rb`: Persists call center audio metadata and agent notes
- `call_center_metrics_job.rb`: Calculates daily call center metrics (pick-up rate, talk time)
- `weekly_seller_onboarding_summary_job.rb`: Generates executive weekly summary of merchant acquisitions
- `monitoring_metric_job.rb`: Periodically samples server health and writes to `monitoring_metrics`
- `monitoring_cleanup_job.rb`: Truncates old monitoring metrics and logs older than retention thresholds
- `application_job.rb`: ActiveJob base class

---

### 4.6 Mailers (`app/mailers/`) (20 files)

- `seller_communications_mailer.rb`: Multi-template mailer for merchant newsletters, guides, and feature updates
- `prospect_mailer.rb`: Cold outreach emails sent to prospective sellers
- `marketing_mailer.rb`: Product review requests, Valentine's promotions, and WhatsApp channel invitations
- `staff_mailer.rb`: Internal alerts sent to staff when accounts are created or updated
- `brand_kenya_mailer.rb`: Onboarding, missing items, and outreach emails for Kenyan brand manufacturers
- `partner_invite_mailer.rb`: Brand partner invitations, reminders, and internal join alerts
- `seller_mailer.rb`: KYC compliance, review request approvals/rejections, document expiration, and QR welcome
- `welcome_mailer.rb`: Immediate welcome email for newly registered buyers and sellers
- `review_mailer.rb`: Customer review notifications to sellers and seller reply alerts to buyers
- `sales_mailer.rb`: Weekly onboarding summaries and performance recaps for the sales team
- `issue_mailer.rb`: Support ticket creation, status update, and comment notifications
- `message_notification_mailer.rb`: Email alerts when a user has unread platform chat messages
- `call_summary_mailer.rb`: Summary email dispatched to clients after a sales call
- `admin_reports_mailer.rb`: Weekly merchant health checkpoints sent to platform administrators
- `data_deletion_mailer.rb`: User confirmation, status updates, and admin alerts for account deletion requests
- `application_mailer.rb`: Base mailer setting default layout (`mailer`), sender address, and styling
- `password_reset_mailer.rb`: Password reset One-Time Password delivery
- `user_mailer.rb`: Account reactivation emails with secure one-click restoration tokens
- `otp_mailer.rb`: Account verification and telephone update One-Time Passwords
- `contact_mailer.rb`: Public contact inquiry forwarding to support and automated customer auto-reply

---

### 4.7 React Email Templates (`app/javascript/emails/`) (68 files)

#### Shared Reusable Email Components (`app/javascript/emails/_components/`) (8 files)
- `email_layout.tsx`: Master responsive HTML email layout with header, footer, and styling
- `header.tsx`: Carbon branding header with logo and navigation links
- `footer.tsx`: Standard legal disclaimer, social links, unsubscribe, and company address
- `button.tsx`: Brand-styled call-to-action button with tracking URL wrapper
- `info_card.tsx`: Highlight box for metric summaries, instructions, or featured products
- `code_block.tsx`: Styled box for OTP codes and merchant verification codes
- `divider.tsx`: Visual dividing line conforming to email client rendering quirks
- `icon.tsx`: Inlined vector and icon renderers for email clients

#### Application JS & Stimulus (`app/javascript/`) (4 files)
- `application.js`: Main JavaScript entrypoint
- `controllers/application.js`: Stimulus application initialization
- `controllers/hello_controller.js`: Sample Stimulus controller
- `controllers/index.js`: Stimulus controller auto-loader

#### React Email Templates by Mailer (56 files)
- **`admin_reports_mailer/`**
  - `weekly_seller_checkpoint.tsx`: Weekly executive digest on merchant acquisitions and activity
- **`brand_kenya_mailer/`**
  - `cold_outreach.tsx`: Outreach pitch to prospective Kenyan manufacturers
  - `complete_profile.tsx`: Action checklist guiding brand partners to finish their profile
  - `missing_items_list.tsx`: Follow-up highlighting unlisted products in partner catalogs
- **`call_summary_mailer/`**
  - `call_summary_email.tsx`: Post-call debrief with action items sent to merchants
- **`contact_mailer/`**
  - `auto_reply.tsx`: Automated confirmation acknowledging receipt of contact form inquiries
  - `contact_form.tsx`: Internal notification displaying submitted customer support requests
- **`data_deletion_mailer/`**
  - `admin_notification.tsx`: Internal alert informing admins of a user data deletion request
  - `status_update.tsx`: Notification informing the user of the progress of their deletion
  - `user_confirmation.tsx`: Initial acknowledgment sent to users requesting account deletion
- **`issue_mailer/`**
  - `comment_added.tsx`: Alert when an admin or agent comments on a support issue
  - `issue_created.tsx`: Confirmation containing issue tracking ticket ID
  - `status_updated.tsx`: Alert when a ticket is resolved, closed, or marked in-progress
- **`marketing_mailer/`**
  - `app_install_nudge.tsx`: Graphic-rich email encouraging mobile application install
  - `product_review_request.tsx`: Post-interaction review request with star rating links
  - `valentines_campaign.tsx`: Seasonal Valentine's marketing campaign with seller highlights
  - `whatsapp_updates_invite.tsx`: Invitation encouraging sellers to join the WhatsApp updates channel
- **`message_notification_mailer/`**
  - `new_message_notification.tsx`: Notification previewing new chat message and sender
- **`otp_mailer/`**
  - `send_otp.tsx`: High-visibility OTP verification email with numeric code block
- **`partner_invite_mailer/`**
  - `expired_internal.tsx`: Internal alert when a brand partner invite expires unredeemed
  - `invite.tsx`: Official brand partnership invitation sent to authorized dealers
  - `joined_internal.tsx`: Internal notification when an invited partner accepts and registers
  - `reminder.tsx`: Reminder sent to merchants who haven't accepted their partner invitation
- **`password_reset_mailer/`**
  - `send_otp_email.tsx`: Security email delivering the 6-digit password reset OTP
- **`review_mailer/`**
  - `reply_posted_notification.tsx`: Alert notifying a buyer that a merchant replied to their review
  - `review_posted_notification.tsx`: Alert notifying a seller that a new review was posted
- **`sales_mailer/`**
  - `weekly_onboarding_summary.tsx`: Digest of sales rep performance, quota progress, and visits
- **`seller_communications_mailer/`**
  - `accurate_listings.tsx`: Best practices on item descriptions, photography, and pricing
  - `ad_visibility_reminder.tsx`: Tips on how to increase listing views and engagement
  - `app_promo.tsx`: Merchant-focused promotion highlighting seller tools in the mobile app
  - `black_friday_email.tsx`: Seller guidance on preparing inventory and discounts for Black Friday
  - `buyers_compare_before_contact.tsx`: Data-driven email showing how buyers comparison-shop
  - `catalog_upload_reminder.tsx`: Reminder highlighting the revenue benefits of uploading catalogs
  - `catalog_upload_request.tsx`: Initial invitation to upload product catalogs for free indexing
  - `custom_communication.tsx`: Flexible administrative template for announcements
  - `general_update.tsx`: General platform news, policy changes, and feature releases
  - `listing_reminder.tsx`: Re-engagement email for merchants with low or stale inventory
  - `new_features.tsx`: Product showcase introducing new platform tools for sellers
  - `partner_catalog_update.tsx`: Alert informing merchants of updated pricing from their brand partner
  - `request_phone_number.tsx`: Requesting merchants to add an active phone number for SMS/WhatsApp
  - `seller_growth_initiative.tsx`: Guidance on scaling revenue through the Carbon platform
  - `share_shop_feature.tsx`: Tutorial on sharing storefront links across social media
- **`seller_mailer/`**
  - `account_flagged.tsx`: Urgent notification detailing policy violations and appeal steps
  - `ad_flagged.tsx`: Notification when an individual listing is rejected by moderation
  - `document_expiry_reminder.tsx`: Reminder that business permits or IDs expire soon
  - `document_update_reminder.tsx`: Reminder to re-submit expired or rejected verification documents
  - `field_verification_notice.tsx`: Notice confirming an upcoming physical visit by a sales agent
  - `reactivation_confirmation.tsx`: Confirmation that a suspended or closed seller account is restored
  - `review_request_approved.tsx`: Approval confirmation for a merchant review submission
  - `review_request_confirmation.tsx`: Acknowledgment that a review request was received
  - `review_request_rejected.tsx`: Explanation of why a review request was rejected
  - `storefront_qr_welcome.tsx`: Delivery of the merchant's high-res printable store QR standee
- **`staff_mailer/`**
  - `account_created.tsx`: Notification to team leads when a new staff user is provisioned
  - `account_updated.tsx`: Security notification when staff permissions or emails are modified
- **`user_mailer/`**
  - `reactivation_email.tsx`: One-click reactivation link for closed user accounts
- **`welcome_mailer/`**
  - `welcome_email.tsx`: Welcome email sent to all new registered users

---

### 4.8 ActiveModel Serializers (`app/serializers/`) (25 files)

- `ad_serializer.rb`: Formats product ads with images, seller verification badges, price, and specs
- `ad_search_serializer.rb`: Serializes search queries and frequency data
- `admin_serializer.rb`: Formats administrator user accounts and permission scopes
- `banner_serializer.rb`: Serializes banner graphics, click URLs, and scheduling dates
- `buyer_serializer.rb`: Formats buyer user profiles, preferences, and saved details
- `category_serializer.rb`: Serializes category trees, icons, and child subcategories
- `click_event_serializer.rb`: Formats click analytics, referrers, and device types
- `conversation_serializer.rb`: Serializes chat threads with participant profiles and latest message
- `county_serializer.rb`: Formats Kenyan counties and associated sub-counties
- `document_type_serializer.rb`: Serializes accepted KYC document requirements
- `faq_serializer.rb`: Formats FAQ question, answer, and category metadata
- `message_serializer.rb`: Serializes individual chat messages with status, attachments, and timestamps
- `offer_serializer.rb`: Serializes price negotiation offers, counter-offers, and status
- `promotion_serializer.rb`: Formats promo codes, percentage discounts, and validity windows
- `review_serializer.rb`: Formats star ratings, customer feedback, and merchant replies
- `seller_analytics_serializer.rb`: Serializes merchant revenue, impressions, and conversion metrics
- `seller_document_serializer.rb`: Formats uploaded KYC documents and verification status
- `seller_serializer.rb`: Comprehensive merchant serializer with tier, branch, and verified badges
- `seller_tier_serializer.rb`: Serializes active seller subscription details and expiry dates
- `sub_county_serializer.rb`: Formats sub-county geographical units
- `subcategory_serializer.rb`: Formats subcategories with parent category references
- `tier_feature_serializer.rb`: Serializes individual feature entitlements belonging to a tier
- `tier_pricing_serializer.rb`: Serializes tier subscription billing options
- `tier_serializer.rb`: Formats subscription plans and their feature matrices
- `wish_list_serializer.rb`: Serializes saved products belonging to a user wishlist

---

### 4.9 Views & Layouts (`app/views/`) (46 files)

- `layouts/application.html.erb`: Default HTML layout wrapper
- `layouts/mailer.text.erb`: Text fallback layout wrapper for ActionMailer
- `authentication/oauth_callback.html.erb`: OAuth popup message handler sending auth tokens to opener
- `seller/catalogs/show.html.erb`: Server-rendered view for reviewing uploaded merchant catalogs
- `seller_communications/general_update.html.erb`: Web fallback view for general communications
- `sitemap/index.xml.erb`: Dynamic XML sitemap template index
- **ActionMailer HTML / Text / MJML Templates:**
  - `admin_reports_mailer/weekly_seller_checkpoint.html.erb` & `.text.erb`
  - `contact_mailer/auto_reply.html.erb` & `contact_form.html.erb`
  - `data_deletion_mailer/admin_notification.html.erb`, `status_update.html.erb`, `user_confirmation.html.erb`
  - `issue_mailer/comment_added.html.erb`, `issue_created.html.erb`, `status_updated.html.erb`
  - `mailers/product_review_request.mjml`
  - `marketing_mailer/valentines_campaign.html.mjml`
  - `message_notification_mailer/new_message_notification.html.erb`
  - `mjml/shared/baseline-head.mjml` (Shared MJML header styles and fonts)
  - `otp_mailer/send_otp.html.erb`
  - `password_reset_mailer/send_otp_email.html.erb`
  - `prospect_mailer/cold_outreach.html.erb` & `.text.erb`
  - `review_mailer/reply_posted_notification.html.erb` & `review_posted_notification.html.erb`
  - `seller_communications_mailer/accurate_listings.mjml`
  - `seller_communications_mailer/app_promo.mjml`
  - `seller_communications_mailer/black_friday2026.html.erb` & `.text.erb`
  - `seller_communications_mailer/black_friday_email.html.erb`
  - `seller_communications_mailer/buyers_compare_before_contact.html.erb`, `.mjml`, `.text.erb`
  - `seller_communications_mailer/custom_communication.html.erb`
  - `seller_communications_mailer/general_update.html.erb`
  - `seller_communications_mailer/listing_reminder.mjml`
  - `seller_communications_mailer/request_phone_number.text.erb`
  - `seller_communications_mailer/seller_growth_initiative.html.mjml` & `.text.erb`
  - `seller_communications_mailer/share_shop_feature.mjml`
  - `seller_mailer/document_expiry_reminder.html.erb` & `document_update_reminder.html.erb`
  - `seller_mailer/sample_performance_report.html.mjml`
  - `user_mailer/reactivation_email.html.erb`
  - `welcome_mailer/welcome_email.html.erb`

---

### 4.10 Channels, Assets & Middleware (`app/channels/`, `app/assets/`, `app/helpers/`, `app/middleware/`) (14 files)

- **Channels (`app/channels/`) (5 files):**
  - `application_cable/channel.rb`: Base ActionCable channel class
  - `application_cable/connection.rb`: Authenticates WebSocket connections using JWT tokens
  - `conversations_channel.rb`: Streams real-time messages, typing indicators, and read marks
  - `notifications_channel.rb`: Streams real-time user notification badges
  - `presence_channel.rb`: Tracks user online / idle / offline status
- **Middleware (`app/middleware/`) (2 files):**
  - `noise_silencer.rb`: Silences health check and monitoring noise in Rails server logs
  - `connection_pool_middleware.rb`: Ensures database and Redis connection pool cleanup across requests
- **Assets (`app/assets/`) (4 files):**
  - `config/manifest.js`: Asset pipeline Sprockets manifest
  - `stylesheets/application.css`: Base CSS styling
  - `images/logo.png`: Carbon platform brand logo
  - `images/.keep`: Git preservation file
- **Helpers (`app/helpers/`) (3 files):**
  - View helper modules for standard formatting

---

### 4.11 Configuration (`config/`) (42 files)

#### Environment & Core Configuration
- `application.rb`: Rails application settings, autoload paths, and middleware stack
- `boot.rb`: Bundler and Bootsnap setup
- `environment.rb`: Rails initialization
- `cable.yml`: ActionCable configuration (Redis adapter in staging/production)
- `database.yml`: PostgreSQL connection settings for dev, test, and production
- `routes.rb`: Complete REST and WebSocket routing declarations
- `puma.rb`: Puma server concurrency, worker, and thread pool settings
- `storage.yml`: ActiveStorage disk and Cloudinary service configurations
- `importmap.rb`: JavaScript import map pin definitions
- `credentials.yml.enc`: Encrypted production API keys and secrets
- `locales/en.yml`: English localization strings
- `sitemap.rb`: Sitemap generator configuration
- `schedule.rb`: Whenever gem crontab configuration
- `schedule.yml`: Sidekiq-cron recurring job schedule configuration
- `sidekiq.yml`: Sidekiq concurrency, queue priorities (`default`, `mailers`, `critical`), and timeouts

#### Environments (`config/environments/`)
- `development.rb`: Development caching, hot-reloading, and debug logs
- `production.rb`: SSL enforcement, Brotli compression, production logging, and asset digests
- `test.rb`: Test environment isolation and mailer delivery disabling

#### Initializers (`config/initializers/`) (24 files)
- `action_cable_logger.rb`: Formatted logging for WebSocket events
- `action_cable_logging.rb`: Detailed ActionCable telemetry
- `anycable.rb`: AnyCable RPC server and broadcast configuration
- `anycable.rb.bak`: AnyCable backup configuration
- `cloudinary.rb`: Cloudinary SDK credentials and transformation presets
- `content_security_policy.rb`: Content Security Policy headers
- `cors.rb`: Rack-CORS rules allowing authorized frontend origins
- `filter_parameter_logging.rb`: Masks sensitive params (passwords, tokens, OTPs) from logs
- `fix_smtp_ssl.rb`: SSL context workaround for SMTP email delivery
- `google_merchant.rb`: Google Content API for Shopping client initialization
- `inflections.rb`: Custom English pluralization rules for domain models
- `mjml.rb`: MJML template engine configuration
- `mjml_fix.rb`: Binary path fallback for MJML compiler
- `omniauth.rb.disabled`: Disabled legacy OmniAuth initializer
- `opentelemetry.rb`: OpenTelemetry SDK setup for distributed traces
- `permissions_policy.rb`: Browser Permissions Policy HTTP headers
- `rack_attack.rb`: Rack::Attack rate limiting rules against brute-force and scraping
- `react_email_rails.rb`: React Email renderer bridge configuration
- `redis.rb`: Redis client and ConnectionPool initialization
- `sentry.rb`: Sentry Ruby and Rails exception capture and performance tracing
- `session_store.rb`: Redis-backed session store configuration
- `sidekiq.rb`: Sidekiq client and server Redis connection pools
- `trigger_phone_campaign_on_deploy.rb`: Post-deploy trigger for merchant phone update campaign
- `webauthn.rb`: WebAuthn origin, RP ID, and algorithm configuration

---

### 4.12 Database Layer (`db/`) (307 files)

- `schema.rb`: Authoritative PostgreSQL database schema definition (1,763 lines)
- `seeds.rb`: Initial seed data (categories, subcategories, tiers, counties, demo accounts)
- `kenyan_counties.json`: Definitive dataset of Kenya's 47 counties and constituencies
- `data/sales_brands.json`: Catalog of authorized Kenyan brands, distributor tiers, and keywords
- `prospect_lists/nairobi-seller-prospects.csv`: Field lead list of Nairobi retail merchants
- `prospect_lists/backup-leads.csv`: Backup lead registry for merchant acquisition outreach
- **Active Record Migrations (`db/migrate/`) (301 files):**  
  Spanning 2024 through 2026, including initial schema creation, PostgreSQL trigram extensions (`enable_trgm_extension.rb`), full-text search indexes (`add_search_indexes_to_ads.rb`), polymorphic notifications, M-Pesa transactions, Google Business Profile tables, KYC documents, OAuth columns, performance indexes, and latest schema updates (`20261023110000_add_deleted_attribution_to_ads.rb`).

---

### 4.13 Library Core, Scripts & Rake Tasks (`lib/`) (73 files)

#### Core Utilities & Middlewares (`lib/`)
- `buyer_details_utility.rb`: Sanitization and privacy masking for buyer contact details
- `marketing_authorize_api_request.rb`: Standalone request authorizer for marketing workers
- `sales_authorize_api_request.rb`: Standalone request authorizer for sales scripts
- `middleware/strip_trailing_dot.rb`: Rack middleware fixing malformed URLs ending with trailing dots
- `assets/.keep`: Directory preservation

#### Maintenance & Diagnostic Scripts (`lib/scripts/`) (22 files)
- `analyze_direct_traffic.rb`: Analyzes unreferred website visits to identify dark social channels
- `check_conversation_messages.rb`: Audits chat conversation message sequences for orphaned entries
- `check_sales_messages.rb`: Checks sales inquiry message response rates
- `check_sitemap.rb`: Verifies that all active product ads are present in sitemaps
- `check_specific_conversation.rb`: Debug tool inspecting a specific conversation ID
- `check_unread_direct.rb`: Tests direct unread badge queries against Redis
- `check_unread_messages.rb`: Audits unread counts across all active users
- `check_utm_data_quality.rb`: Identifies dirty, malformed, or missing UTM parameters
- `check_utm_tracking_records.rb`: Validates attribution records in the analytics table
- `export_clean_utm_records.rb`: Exports sanitized marketing attribution logs to CSV
- `export_pantech_ads.rb`: Exports product ads for partner Pantech Kenya Limited
- `fix_duplicate_utm_params.rb`: Deduplicates corrupted UTM parameters in analytics tables
- `fix_utm_normalization_issues.rb`: Cleans casing and spacing in UTM campaigns
- `generate_pantech_html.rb`: Generates custom HTML showcase for Pantech products
- `normalize_source_column.rb`: Normalizes legacy source strings in analytics records
- `normalize_utm_sources.rb`: Standardizes `utm_source` values across campaign history
- `render_qr_standee.cjs`: Node script rendering vector SVG QR standees to print-ready PNG
- `review_campaign_final.rb`: Dispatches the post-purchase review generation campaign
- `review_campaign_manager.rb`: Manages schedules and cohorts for product review emails
- `show_clean_utm_records.rb`: Terminal viewer for validated UTM records
- `show_incomplete_utm_records.rb`: Terminal viewer for unclassified traffic sources
- `test_unread_api.rb`: Tests API endpoint responses for unread message counters

#### Rake Tasks (`lib/tasks/`) (45 files)
- `ad_quality_enrichment.rake`: Analyzes and scores ad quality across existing listings
- `backfill_click_events.rake`: Backfills missing referral and session metadata into click events
- `backfill_seller_category_placement.rake`: Computes and assigns initial category placement scores
- `black_friday_anchors.rake`: Seeds and pins featured anchor deals for Black Friday
- `black_friday_email.rake`: Triggers test and bulk sends of the Black Friday email campaign
- `brand_kenya.rake`: Syncs Brand Kenya certified manufacturers and products
- `broadcast.rake`: Broadcasts urgent platform announcements to all connected WebSockets
- `catalog_upload_reminder.rake`: Re-enqueues catalog upload reminders for inactive sellers
- `catalog_upload_request.rake`: Sends catalog upload invitations to newly registered sellers
- `check_fake_numbers.rake`: Scans merchant database for invalid, dummy, or fraudulent phone numbers
- `cleanup_coarse_geocodes.rake`: Cleans up low-resolution geocodes requiring re-pinning
- `create_whatsapp_template.rake`: Submits new message templates to Meta for approval
- `document_expiry.rake`: Daily cron task identifying expired business permits
- `export_sellers_by_date_range.rake`: Exports merchant registries within specific date windows
- `fix_missing_profile_pictures.rake`: Repairs broken avatar URLs with default placeholders
- `fix_sequences.rake`: Resets PostgreSQL auto-incrementing primary key sequences
- `friday_seller_checkpoint.rake`: Compiles and delivers Friday merchant performance checkpoints
- `generate_manual_review_csv.rake`: Dumps flagged listings into CSV for human moderator review
- `geocode_preview.rake`: Dry-run preview of pending address geocodes
- `geocode_preview2.rake`: Secondary preview utility for Nominatim address parsing
- `geocode_report.rake`: Generates geographic coverage and accuracy reports
- `google_place_reviews.rake`: Triggers Google Maps Place review scraping and cache updates
- `import_whatsapp_reports.rake`: Imports WhatsApp delivery and engagement reports
- `mpesa_register.rake`: Registers validation and confirmation URLs with Safaricom Daraja API
- `phone_update_campaign.rake`: Executes SMS/email campaign prompting sellers to add phone numbers
- `production_sync.rake`: Sanitizes and imports production catalog subsets into staging
- `prospect_outreach.rake`: Dispatches cold acquisition emails to prospective seller lists
- `qr.rake`: Batch-generates printable QR code assets for registered physical stores
- `regeocode_all_sellers.rake`: Forces a complete re-geocoding of all merchant physical addresses
- `regeocode_sellers_nominatim.rake`: Re-geocodes addresses using the OpenStreetMap Nominatim engine
- `sales_brands.rake`: Imports brand and distributor mappings from `sales_brands.json`
- `search_analytics.rake`: Consolidates and analyzes high-frequency search keywords
- `seller_performance.rake`: Evaluates merchant responsiveness, ratings, and listing completeness
- `send_accurate_listings_whatsapp.rake`: Dispatches WhatsApp educational tips on ad accuracy
- `send_listing_update_whatsapp.rake`: Dispatches WhatsApp prompts to refresh stale listings
- `send_product_details_whatsapp.rake`: Dispatches WhatsApp guides on detailed product descriptions
- `send_shop_identity_whatsapp.rake`: Dispatches WhatsApp prompts to upload storefront branding
- `setup.rake`: Automated application setup (`bundle install`, `db:migrate`, `db:seed`)
- `test_seller_email.rake`: Test utility sending sample merchant emails to developers
- `update_seller_coordinates.rake`: Applies manual coordinate overrides to merchant stores
- `valentines_email.rake`: Executes Valentine's promotional marketing dispatch
- `verify_seller_coordinates.rake`: Validates that store coordinates lie within Kenyan borders
- `whatsapp_catalog_template.rake`: Tests WhatsApp catalog promotional templates
- `whatsapp_partner_templates.rake`: Tests WhatsApp brand partner notifications
- `whatsapp_updates_invite.rake`: Sends bulk invites to the Carbon WhatsApp channel
- `.keep`: Git directory preservation

---

### 4.14 Catalog Generation, Scrapers & Expansion Data (`scripts/`) (111 files)

#### Scraper & Generation Scripts (27 files)
- `add_missing_brands.rb`: Inserts missing brand metadata into existing ad listings
- `benchmark_content_moderation.rb`: Measures latency and throughput of the AI safety engine
- `benchmark_gsmarena.rb`: Tests GSM Arena API scraping and specs extraction speeds
- `bulk_send_app_promo.rb`: Bulk sender for mobile app promotional announcements
- `check_all_catalogs.rb`: Validates JSON structure across all generated category catalogs
- `check_catalog_coverage.rb`: Reports the percentage of catalog items mapped to live ads
- `dry_run_buyers_compare_job.rb`: Simulates "Buyers Compare" campaign recipient selection
- `dry_run_phone_update_campaign.rb`: Simulates phone number update campaign targeting
- `dry_run_verify_before_buying_all.rb`: Simulates buyer safety notification dispatch
- `extract_text.swift`: Native Swift macOS OCR script extracting text from product images
- `generate_apple_specs.rb`: Generates comprehensive hardware specs for Apple devices
- `generate_automotive.rb`: Generates automotive parts and accessories catalog
- `generate_catalog_inventory.rb`: Main catalog inventory synthesis script
- `generate_computers.rb`: Generates desktop and workstation catalog datasets
- `generate_tvs.rb`: Generates television and audio gear catalog datasets
- `generate_zero_model_samples.rb`: Generates benchmark data for zero-shot categorization
- `merge_catalog_expansion.py`: Python script merging and deduplicating expanded category JSONs
- `mjml_mock`: Executable mock for compiling MJML templates in test environments
- `rebuild_catalogs.rb`: Orchestrates complete re-generation of all category inventory catalogs
- `scrape_agriculture.rb`: Scraper collecting Kenyan agricultural supplies and farm machinery
- `scrape_apple_specs.rb`: Scrapes technical specifications from official Apple support pages
- `scrape_apple_targeted.rb`: Targeted scraper for specific iPhone and iPad model variations
- `scrape_automotive_parts.rb`: Scrapes automotive spare parts catalogs and compatibility tables
- `scrape_computer_accessories.rb`: Scrapes PC peripherals, monitors, and networking equipment
- `scrape_electronics_accessories.rb`: Scrapes consumer electronics accessories
- `scrape_filtration.rb`: Scrapes industrial and automotive fuel/water filtration catalogs
- `scrape_gsm_arena.rb`: GSM Arena scraper for smartphones, tablets, and smartwatches
- `scrape_hardware_tools.rb`: Scrapes construction tools, power equipment, and hardware
- `scrape_laptops.rb`: Scrapes laptop computer specifications and configurations
- `scrape_tv_audio_streaming.rb`: Scrapes smart TVs, home audio, and streaming devices

#### Generated & Filtered Catalog Datasets (`scripts/output/`) (84 JSON files)
Contains canonical catalog data, filtered subsets, and expansion iterations powering autocomplete and structured ad creation:
- Primary catalogs: `agriculture.json`, `automotive.json`, `automotive_parts.json`, `computers.json`, `computer_accessories.json`, `electronics_accessories.json`, `filtration.json`, `hardware_tools.json`, `laptops.json`, `phones.json`, `tablets.json`, `tvs.json`, `tv_audio_streaming.json`, `apple_computers.json`
- Filtered high-quality variants: `*_filtered.json` (14 files)
- Expansion datasets (`scripts/output/expansion/`): 12 files
- Expansion v2 datasets (`scripts/output/expansion2/`): 14 files
- Checkpoints & Backups (`scripts/output/backup_20261001_130739/`): 17 files

---

### 4.15 Test Suites (`spec/` & `test/`) (121 files)

#### RSpec Test Suite (`spec/`) (36 files)
- `spec_helper.rb`: Base RSpec test framework configuration
- `rails_helper.rb`: Rails environment loading and database cleaner setup
- **Factories (`spec/factories/`) (12 files):**
  - `branches.rb`, `call_queues.rb`, `call_records.rb`, `comment_votes.rb`, `email_communication_logs.rb`, `marketing_users.rb`, `monitoring_errors.rb`, `monitoring_metrics.rb`, `notifications.rb`, `offer_ads.rb`, `review_requests.rb`, `search_analytics.rb`
- **Model Specs (`spec/models/`) (13 files):**
  - `ad_spec.rb`, `branch_spec.rb`, `call_queue_spec.rb`, `call_record_spec.rb`, `comment_vote_spec.rb`, `email_communication_log_spec.rb`, `marketing_user_spec.rb`, `monitoring_error_spec.rb`, `monitoring_metric_spec.rb`, `notification_spec.rb`, `offer_ad_spec.rb`, `review_request_spec.rb`, `search_analytic_spec.rb`
- **Request Specs (`spec/requests/`) (5 files):**
  - `buyer_ads_search_spec.rb`: Tests full-text search, filters, and pagination
  - `seller_ads_spec.rb`: Tests merchant ad creation, editing, and deletion
  - `seller_catalog_spec.rb`: Tests bulk catalog ingestion API
  - `vendor_spec.rb`: Tests legacy vendor endpoints
  - `schema.rb`: Schema verification helper
- **Job Specs (`spec/jobs/`) (2 files):**
  - `send_catalog_upload_reminder_to_new_sellers_job_spec.rb`
  - `send_whatsapp_updates_invite_job_spec.rb`
- **Service Specs (`spec/services/`) (2 files):**
  - `google_merchant_service_spec.rb`: Verifies Google Shopping feed generation
  - `google_merchant_text_sanitizer_spec.rb`: Verifies text policy cleaning for merchant feeds

#### Rails Minitest Suite (`test/`) (85 files)
- `test_helper.rb`: Minitest ActiveSupport test configuration
- `application_system_test_case.rb`: System test headless browser setup
- **Controller Tests (`test/controllers/`) (16 files):**
  - `abouts_controller_test.rb`, `click_events_controller_test.rb`, `conversations_controller_test.rb`, `email_otps_controller_test.rb`, `faqs_controller_test.rb`, `home_controller_test.rb`, `messages_controller_test.rb`, `products_controller_test.rb`, `purchasers_controller_test.rb`, `reviews_controller_test.rb`, `vendors_controller_test.rb`
  - `admin/banners_controller_test.rb`, `admin/sellers_controller_test.rb`
  - `sales/analytics_controller_test.rb`
  - `seller/analytics_controller_test.rb`
- **Model Tests (`test/models/`) (25 files):**
  - `about_test.rb`, `admin_test.rb`, `analytic_test.rb`, `banner_test.rb`, `branch_test.rb`, `category_test.rb`, `click_event_test.rb`, `cms_page_test.rb`, `conversation_test.rb`, `document_type_test.rb`, `email_otp_test.rb`, `faq_test.rb`, `invoice_test.rb`, `message_test.rb`, `notification_test.rb`, `order_test.rb`, `password_otp_test.rb`, `payment_test.rb`, `product_test.rb`, `promotion_test.rb`, `review_test.rb`, `sales_user_test.rb`, `shipment_test.rb`, `user_test.rb`, `vehicle_type_test.rb`, `vendor_test.rb`
- **Fixtures (`test/fixtures/`) (27 files):**
  - YAML fixtures for all legacy and core models (abouts, admins, analytics, banners, categories, cms_pages, conversations, document_types, email_otps, faqs, invoices, messages, notifications, orders, password_otps, payments, products, promotions, reviews, riders, sales_users, shipments, users, vehicle_types, vendors, and `.keep`)
- **Mailer Tests & Previews (`test/mailers/`) (4 files):**
  - `otp_mailer_test.rb`, `password_reset_mailer_test.rb`, `vendor_mailer_test.rb`
  - Previews: `otp_mailer_preview.rb`, `password_reset_mailer_preview.rb`, `vendor_mailer_preview.rb`
- **Channel Tests (`test/channels/`) (2 files):**
  - `application_cable/connection_test.rb`, `notifications_channel_test.rb`
- **Job Tests (`test/jobs/`) (1 file):**
  - `geocode_sellers_job_test.rb`
- **Service Tests (`test/services/`) (1 file):**
  - `unread_message_reminder_service_test.rb`
- **Keep files (7 files):**
  - `.keep` files in `controllers/`, `fixtures/files/`, `helpers/`, `integration/`, `mailers/`, `models/`, `system/`

---

### 4.16 Public Assets & Static Web (`public/`) (28 files)

- `404.html`: Standard HTTP 404 Not Found error page
- `422.html`: Standard HTTP 422 Unprocessable Entity error page
- `500.html`: Standard HTTP 500 Internal Server Error page
- `robots.txt`: Search crawler directives
- `oauth-callback.js`: Lightweight JavaScript handler transmitting OAuth authentication tokens to parent windows
- `favicon.ico`: Platform favicon icon
- `apple-touch-icon.png` & `apple-touch-icon-precomposed.png`: iOS home screen app icons
- `email_banner_buyers_compare.png`: Header graphic for "Buyers Compare" email campaign
- `email_banner_new_features.png`: Header graphic for "New Features" email campaign
- `cached_profile_pictures/` (18 `.jpg` files): Locally cached and optimized user avatar images

---

### 4.17 Binstubs & Deployment Executables (`bin/`) (7 files)

- `anycable-go`: Pre-compiled AnyCable-Go binary (Mach-O / ELF) running high-concurrency WebSocket multiplexing
- `bundle`: Bundler binstub
- `importmap`: Rails importmap command runner
- `rails`: Primary Rails CLI binstub
- `rake`: Rake task execution binstub
- `render-build.sh`: Build script executing `bundle install`, asset precompilation, and database migrations on Render
- `setup`: Automated local environment setup script

---

### 4.18 Documentation & CI (`docs/`, `.github/`) (2 files)

- `docs/EMAIL_INVENTORY.md`: Comprehensive audit document cataloging every transactional and marketing email in the platform
- `.github/workflows/ci.yml`: GitHub Actions automated CI workflow (running RuboCop, RSpec, and Minitest)

---

### 4.19 Runtime State Placeholders (`log/`, `storage/`, `tmp/`, `vendor/`) (7 files)

- `log/.keep`: Preserves `log/` directory while ignoring log files
- `storage/.keep`: Preserves `storage/` directory while ignoring local file uploads
- `tmp/.keep`, `tmp/pids/.keep`, `tmp/storage/.keep`: Preserves temporary directory trees
- `vendor/.keep`, `vendor/javascript/.keep`: Preserves third-party vendor directories

---

## 5. Architectural Insights & Recommendations

1. **Email Template Consolidation:**  
   The codebase features a modern TypeScript/React Email system in `app/javascript/emails/` (56 templates), but still contains legacy `.html.erb` and `.mjml` templates in `app/views/`. Retiring the legacy ERB/MJML files in favor of the React Email pipeline will streamline maintenance.
2. **Dual Test Suite Unification:**  
   The project currently maintains both `spec/` (RSpec, 36 files) and `test/` (Minitest, 85 files). Consolidating new test coverage into RSpec while maintaining or migrating existing Minitest controller specs will simplify CI run times and test conventions.
3. **Catalog Data Organization:**  
   `scripts/output/` contains 84 JSON files totaling significant catalog expansion data. Archiving historical backup folders (`backup_20261001_130739`) or moving raw datasets to S3/Cloudflare R2 can reduce repository footprint.
4. **AnyCable-Go Binary:**  
   `bin/anycable-go` is committed as a compiled binary in the repository. Standardizing installation via Dockerfile or buildpack download script during deployment (`render-build.sh`) will keep the git history lean and ensure architecture compatibility across Linux x86_64 and ARM environments.
