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
