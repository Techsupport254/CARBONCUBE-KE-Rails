class DeviceToken < ApplicationRecord
  belongs_to :user, polymorphic: true

  validates :token, presence: true, uniqueness: { scope: [:user_type, :user_id] }
  validates :platform, inclusion: { in: %w[ios android web] }, allow_nil: true
end
