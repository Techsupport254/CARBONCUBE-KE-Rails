# frozen_string_literal: true

class GoogleBusinessProfileConnection < ApplicationRecord
  belongs_to :seller

  validates :seller_id, uniqueness: true
  validates :status, inclusion: { in: %w[connected disconnected error] }

  def access_token
    decrypt_token(access_token_ciphertext)
  end

  def access_token=(value)
    self.access_token_ciphertext = encrypt_token(value)
  end

  def refresh_token
    decrypt_token(refresh_token_ciphertext)
  end

  def refresh_token=(value)
    self.refresh_token_ciphertext = encrypt_token(value)
  end

  def connected?
    status == 'connected' && refresh_token.present?
  end

  private

  def encrypt_token(value)
    return if value.blank?

    token_encryptor.encrypt_and_sign(value)
  end

  def decrypt_token(value)
    return if value.blank?

    token_encryptor.decrypt_and_verify(value)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def token_encryptor
    key = Rails.application.key_generator.generate_key('google-business-profile-tokens', 32)
    ActiveSupport::MessageEncryptor.new(key)
  end
end
