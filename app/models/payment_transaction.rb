class PaymentTransaction < ApplicationRecord
  belongs_to :seller
  belongs_to :tier
  belongs_to :tier_pricing
  has_one :seller_tier, dependent: :nullify

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :phone_number, presence: true
  validates :status, presence: true, inclusion: { 
    in: %w[initiated pending processing completed failed cancelled] 
  }
  validates :transaction_type, presence: true
  validates :checkout_request_id, presence: true, uniqueness: true
  validates :merchant_request_id, presence: true, uniqueness: true

  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { order(created_at: :desc) }

  # Check if payment is still valid (not expired)
  def expired?
    return false if status == 'completed' || status == 'failed'
    
    # STK Push payments expire after 10 minutes
    created_at < 10.minutes.ago
  end

  # Check if payment can be retried
  def can_retry?
    status == 'failed' && created_at > 1.hour.ago
  end

  # Get payment status description
  def status_description
    case status
    when 'initiated'
      'Payment initiated'
    when 'pending'
      'Waiting for payment confirmation'
    when 'processing'
      'Processing payment'
    when 'completed'
      'Payment completed successfully'
    when 'failed'
      'Payment failed'
    when 'cancelled'
      'Payment cancelled'
    else
      'Unknown status'
    end
  end

  # Get formatted amount
  def formatted_amount
    "KES #{amount.to_i.to_s.reverse.gsub(/(\d{3})(?=.)/, '\\1,').reverse}"
  end

  # Get payment duration
  def duration_description
    "#{tier_pricing.duration_months} #{'month'.pluralize(tier_pricing.duration_months)}"
  end

  # Auto-expire pending payments
  def self.expire_pending_payments
    where(status: 'pending')
      .where('created_at < ?', 10.minutes.ago)
      .update_all(status: 'failed', error_message: 'Payment expired')
  end

  # Clean up old failed payments
  def self.cleanup_old_payments
    where(status: 'failed')
      .where('created_at < ?', 30.days.ago)
      .destroy_all
  end

  # Check if payment can be cancelled
  def can_cancel?
    ['initiated', 'pending', 'processing'].include?(status) && 
    created_at > 10.minutes.ago
  end

  # Check if this is a duplicate payment for the same seller and tier
  def duplicate_payment?
    PaymentTransaction.where(
      seller_id: seller_id,
      tier_id: tier_id,
      status: ['initiated', 'pending', 'processing']
    ).where.not(id: id).exists?
  end

  # Check if seller already has active subscription for this tier
  def seller_has_active_subscription?
    seller.seller_tier&.tier_id == tier_id && 
    !seller.seller_tier.expired?
  end

  # Validate upgrade is valid (higher tier)
  def valid_upgrade?
    current_tier = seller.seller_tier&.tier
    return true unless current_tier # No current subscription, any tier is valid
    
    tier_id > current_tier.id
  end

  # Get payment age in minutes
  def age_in_minutes
    ((Time.current - created_at) / 1.minute).round
  end

  # Check if payment is stale (older than 30 minutes)
  def stale?
    created_at < 30.minutes.ago
  end

  # Scope for active payments (not completed, failed, or cancelled)
  scope :active, -> { where(status: ['initiated', 'pending', 'processing']) }
  
  # Scope for recent payments (last 24 hours)
  scope :recent_24h, -> { where('created_at > ?', 24.hours.ago) }
  
  # Scope for payments by seller
  scope :for_seller, ->(seller_id) { where(seller_id: seller_id) }
  
  # Scope for payments by tier
  scope :for_tier, ->(tier_id) { where(tier_id: tier_id) }

  after_update :send_status_notification, if: :saved_change_to_status?

  private

  def send_status_notification
    begin
      return unless ['completed', 'failed'].include?(status)

      tokens = DeviceToken.where(user: seller).pluck(:token)
      return unless tokens.any?

      if status == 'completed'
        payload = {
          title: "Payment Successful!",
          body: "Your subscription to #{tier.name} is now active.",
          data: {
            type: 'payment_success',
            transaction_id: id,
            tier_id: tier_id
          }
        }
      elsif status == 'failed'
        payload = {
          title: "Payment Failed",
          body: "Transaction for #{tier.name} could not be completed. #{error_message}",
          data: {
            type: 'payment_failed',
            transaction_id: id
          }
        }
      end
      
      PushNotificationService.send_notification(tokens, payload) if payload
    rescue => e
      Rails.logger.error "Failed to send payment push notification: #{e.message}"
    end
  end
end
