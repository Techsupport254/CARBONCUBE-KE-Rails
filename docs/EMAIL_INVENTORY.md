# Carbon Cube Kenya — Complete Email Inventory

> Verified against codebase on 2026-07-22.
> Every email the system can send to users, grouped by category.

---

## 1. Authentication & Account Management

| # | Email | Mailer | Trigger | Recipient |
|---|-------|--------|---------|-----------|
| 1 | **Welcome Email** | `WelcomeMailer.welcome_email` | Sent immediately after a buyer or seller successfully registers. Called from `BuyersController#create`, `Seller::ProfilesController` (upgrade & onboarding flows). | Buyer / Seller |
| 2 | **OTP Verification** | `OtpMailer.send_otp` | Sends a One-Time Password for verifying email/phone during registration or profile updates. Called from `EmailOtpsController`, `Buyer::ProfilesController`, `Seller::ProfilesController`. | Buyer / Seller |
| 3 | **Password Reset OTP** | `PasswordResetMailer.send_otp_email` | Sends a One-Time Password when a user requests a password reset. Called from `PasswordOtp` model. | Buyer / Seller |
| 4 | **Account Reactivation** | `UserMailer.reactivation_email` | Sent with a secure link to reactivate a previously deactivated/deleted account. Called from `AuthenticationController#reactivate_account`. | Buyer / Seller |

## 2. Messaging & Communication

| # | Email | Mailer | Trigger | Recipient |
|---|-------|--------|---------|-----------|
| 5 | **New Message Notification** | `MessageNotificationMailer.new_message_notification` | Alerts a user when they receive a new chat message on the platform. Called from `Message` model and `MessagesController` (test endpoint). | Buyer / Seller |

## 3. Reviews & Feedback

| # | Email | Mailer | Trigger | Recipient |
|---|-------|--------|---------|-----------|
| 6 | **New Review Notification** | `ReviewMailer.review_posted_notification` | Notifies a seller that a buyer has left a review on one of their products. Called from `Review` model (`after_create`). | Seller |
| 7 | **Review Reply Notification** | `ReviewMailer.reply_posted_notification` | Notifies a buyer that the seller has responded to their review. Called from `Review` model (`after_update` on `seller_reply`). | Buyer |
| 8 | **Post-Purchase Review Request** | `MarketingMailer.product_review_request` | Automated marketing email asking buyers to review recently purchased/interacted products. Called from `lib/scripts/review_campaign_final.rb`. | Buyer / Seller |

## 4. Seller Operations & Compliance

| # | Email | Mailer | Trigger | Recipient |
|---|-------|--------|---------|-----------|
| 9 | **Document Expiry Reminder** | `SellerMailer.document_expiry_reminder` | Alerts sellers that their verification documents are about to expire (1-month before). Triggered via rake task `documents:send_reminders`. | Seller |
| 10 | **Document Update Reminder** | `SellerMailer.document_update_reminder` | Prompts sellers to upload or update expired/rejected verification documents (3-month after expiry). Triggered via rake task `documents:send_reminders`. | Seller |

## 5. Seller Growth & Education (Newsletters / Campaigns)

| # | Email | Mailer | Trigger | Recipient |
|---|-------|--------|---------|-----------|
| 11 | **General Updates** | `SellerCommunicationsMailer.general_update` | Platform news and general announcements. Called from `SendSellerCommunicationJob`, `SellerCommunicationsController`, `Admin::SellerCommunicationsController`. | Seller |
| 12 | **Growth Initiative** | `SellerCommunicationsMailer.seller_growth_initiative` | Tips, strategies, and resources to help sellers increase sales. Triggered via standalone scripts only (`scripts/send_seller_growth_initiative.rb`). | Seller |
| 13 | **Listing Reminders** | `SellerCommunicationsMailer.listing_reminder` | Prompts inactive sellers to add new inventory or update existing listings. Called from `SendSellerCommunicationJob`. | Seller |
| 14 | **Accurate Listings Guide** | `SellerCommunicationsMailer.accurate_listings` | Educational email on writing high-quality, accurate product descriptions. Called from `SendSellerCommunicationJob`. | Seller |
| 15 | **Share Shop Feature** | `SellerCommunicationsMailer.share_shop_feature` | Explains and encourages sellers to use the "Share Shop" feature. Called from `SendSellerCommunicationJob`. | Seller |
| 16 | **App Promotion** | `SellerCommunicationsMailer.app_promo` | Encourages sellers/buyers to download and use the mobile app. Triggered via standalone script only (`scripts/bulk_send_app_promo.rb`). **Not handled by `SendSellerCommunicationJob`** (falls to `else` → error log). | Seller / Buyer |
| 17 | **Black Friday Campaign** | `SellerCommunicationsMailer.black_friday_email` | Promotional campaign for Black Friday. **Currently disabled** — `SendSellerCommunicationJob` returns early without sending. | Seller |
| 18 | **Custom Communication** | `SellerCommunicationsMailer.custom_communication` | Flexible template used by admins to send customized one-off blast emails. Called from `SendSellerCommunicationJob`, `Sales::CallCenterController`. | Seller / Buyer |
| 19 | **Valentine's Campaign** | `MarketingMailer.valentines_campaign` | Seasonal promotional campaign with seller performance data. Triggered via rake tasks only (`valentines:test_send`, `valentines:send_bulk`). | Seller |

## 6. Customer Support & Issue Tracking

| # | Email | Mailer | Trigger | Recipient |
|---|-------|--------|---------|-----------|
| 20 | **Contact Form Auto-Reply** | `ContactMailer.auto_reply` | Automated confirmation email sent to a user after they submit the "Contact Us" form. Called from `ContactController`. | User |
| 21 | **Contact Form → Admin** | `ContactMailer.contact_form` | Sends the user's contact form submission to the admin team. Called from `ContactController`. | Admin |
| 22 | **Issue Created** | `IssueMailer.issue_created` | Confirmation sent to a user when they open a support ticket. Called from `Issue` model (`after_create`). | User |
| 23 | **Issue Status Update** | `IssueMailer.status_updated` | Notifies the user when their support ticket status changes. Called from `Issue` model (`after_update`) and `Admin::IssuesController`. | User |
| 24 | **Issue Comment Added** | `IssueMailer.comment_added` | Alerts the user when an admin/support agent replies to their ticket. Called from `IssueComment` model. | User |

## 7. Data Privacy & Account Deletion

| # | Email | Mailer | Trigger | Recipient |
|---|-------|--------|---------|-----------|
| 25 | **Deletion Request Confirmation** | `DataDeletionMailer.user_confirmation` | Confirms receipt of a user's request to permanently delete their account and data. Called from `DataDeletionController`. | User |
| 26 | **Deletion Request → Admin** | `DataDeletionMailer.admin_notification` | Alerts admin staff of a new deletion request. Called from `DataDeletionController`. | Admin |
| 27 | **Deletion Status Update** | `DataDeletionMailer.status_update` | ⚠️ **Defined but never invoked.** The method exists in the mailer but no controller, model, or job calls it. Intended to notify users when their data has been wiped. | User |

## 8. Call Center

| # | Email | Mailer | Trigger | Recipient |
|---|-------|--------|---------|-----------|
| 28 | **Call Summary Email** | `CallSummaryMailer.call_summary_email` | Sent after a sales call with a summary and rating link. Called from `CallPersistJob`. | Customer |

## 9. Non-Rails Emails (sent via Next.js Call-Center API)

| # | Email | API Endpoint | Trigger | Recipient |
|---|-------|-------------|---------|-----------|
| 29 | **Profile Completion Campaign** | `POST /api/send-profile-completion` | Campaign email to sellers with incomplete profiles (missing enterprise name, description, photo, etc.). Called from `SendProfileCompletionCampaignJob`. | Seller |
| 30 | **Buying Safety Campaign** | `POST /api/send-safety` | Safety-tips email encouraging informed purchasing decisions. Called from `SendUserBuyingSafetyCampaignJob` (bulk via `SendBulkBuyingSafetyCampaignJob`). | Buyer / Seller |

## 10. Internal-Only Emails (Admin)

| # | Email | Mailer | Trigger | Recipient |
|---|-------|--------|---------|-----------|
| 31 | **Weekly Seller Checkpoint** | `AdminReportsMailer.weekly_seller_checkpoint` | Weekly PDF/CSV report of new sellers. Triggered via rake task `admin:friday_seller_checkpoint`. | Admin |

---

## Summary

| Category | Count |
|----------|-------|
| User-facing emails (Rails mailers) | 24 |
| User-facing emails (Next.js API) | 2 |
| Admin-internal emails | 3 |
| Disabled / dead code | 2 |
| **Total defined** | **31** |

### Flags

- **`DataDeletionMailer.status_update`** — defined but never called (dead code).
- **`SellerCommunicationsMailer.black_friday_email`** — explicitly disabled in `SendSellerCommunicationJob` (returns early).
- **`SellerCommunicationsMailer.app_promo`** — not handled by the job dispatcher; only works via standalone scripts.
- **`SellerCommunicationsMailer.seller_growth_initiative`** — only invoked from standalone scripts, not from app code.
- **`MarketingMailer.valentines_campaign`** — only invoked from rake tasks.
- **`SellerMailer.document_expiry_reminder` / `document_update_reminder`** — only invoked from rake tasks.
