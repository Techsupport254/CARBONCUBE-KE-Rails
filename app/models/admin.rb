class Admin < ApplicationRecord
    has_many :sent_messages, as: :sender, class_name: 'Message'
    has_many :conversations
    has_many :notifications, as: :notifiable
    has_many :password_otps, as: :otpable, dependent: :destroy
    
    validates :username, presence: true,
              format: { with: /\A[a-zA-Z0-9_]{3,20}\z/,
                        message: "must be 3-20 characters and contain only letters, numbers, and underscores (no spaces or hyphens)" }
    validates :fullname, presence: true
    validates :email, presence: true, uniqueness: true
    validates :phone_number, length: { is: 10, message: "must be exactly 10 digits" },
              format: { with: /\A\d{10}\z/, message: "should only contain numbers" },
              allow_blank: true

    has_secure_password

    scope :active, -> { where(active: true) }
    scope :deactivated, -> { where(active: false) }

    def deleted?
      !active?
    end

    def active?
      active != false
    end

    def deactivated?
      !active?
    end

    def deactivate!
      update(active: false, deactivated_at: Time.current)
    end

    def reactivate!
      update(active: true, deactivated_at: nil)
    end
    
    def user_type
      'admin'
    end
end
