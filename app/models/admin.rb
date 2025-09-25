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

    has_secure_password
    
    def deleted?
      false
    end
    
    def user_type
      'admin'
    end
end
