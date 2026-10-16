class DeviceToken < ApplicationRecord
  belongs_to :user, polymorphic: true, optional: true

  validates :token, presence: true, uniqueness: true
  validates :platform, inclusion: { in: %w[ios android web] }, allow_nil: true

  scope :guest, -> { where(user_id: nil) }
  scope :registered, -> { where.not(user_id: nil) }
  scope :ios, -> { where(platform: 'ios') }
  scope :android, -> { where(platform: 'android') }
  scope :web, -> { where(platform: 'web') }

  def guest?
    user_id.nil?
  end

  # Single source of truth for mobile app install KPIs across analytics and app installs controllers
  def self.mobile_app_kpis
    mobile_tokens = where(platform: %w[android ios])
    total_installs = mobile_tokens.count

    sellers_with_app = where(user_type: "Seller", platform: %w[android ios]).select(:user_id).distinct.count
    total_sellers = Seller.where(deleted: false).count
    seller_adoption_pct = total_sellers.positive? ? (sellers_with_app.to_f / total_sellers * 100).round(1) : 0.0

    buyers_with_app = where(user_type: "Buyer", platform: %w[android ios]).select(:user_id).distinct.count
    total_buyers = Buyer.where(deleted: false).count
    buyer_adoption_pct = total_buyers.positive? ? (buyers_with_app.to_f / [total_buyers, 1].max * 100).round(1) : 0.0

    sales_staff_with_app = where(user_type: "SalesUser", platform: %w[android ios]).select(:user_id).distinct.count
    unique_users = sellers_with_app + buyers_with_app + sales_staff_with_app
    guests_count = where(user_id: nil, platform: %w[android ios]).count

    android_count = mobile_tokens.where(platform: "android").count
    ios_count = mobile_tokens.where(platform: "ios").count
    active_7d = mobile_tokens.where("updated_at >= ?", 7.days.ago).count
    active_30d = mobile_tokens.where("updated_at >= ?", 30.days.ago).count

    {
      total_installs: total_installs,
      total_devices: total_installs,
      unique_users: unique_users,
      total_installed_users: unique_users,
      sellers_count: sellers_with_app,
      sellers_with_app: sellers_with_app,
      total_sellers: total_sellers,
      seller_adoption_pct: seller_adoption_pct,
      seller_adoption_rate: seller_adoption_pct,
      buyers_count: buyers_with_app,
      buyers_with_app: buyers_with_app,
      total_buyers: total_buyers,
      buyer_adoption_pct: buyer_adoption_pct,
      buyer_adoption_rate: buyer_adoption_pct,
      sales_staff_count: sales_staff_with_app,
      sales_with_app: sales_staff_with_app,
      guests_count: guests_count,
      guests_with_app: guests_count,
      android_count: android_count,
      ios_count: ios_count,
      platform_breakdown: {
        android: android_count,
        ios: ios_count
      },
      active_7d: active_7d,
      active_30d: active_30d
    }
  end

  after_commit :complete_app_install_campaign, on: [:create, :update]

  private

  def complete_app_install_campaign
    return if user_id.blank? || !%w[ios android].include?(platform)

    AppInstallNudgeCampaign
      .where(user_type: user_type, user_id: user_id, status: %w[enrolled active])
      .update_all(status: 'completed', completed_at: Time.current)
  rescue StandardError => e
    Rails.logger.warn "DeviceToken: Failed to complete app install campaign for #{user_type}##{user_id}: #{e.message}"
  end
end
