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
end
