class SalesUser < ApplicationRecord
  has_many :carbon_codes, as: :associable, dependent: :nullify
  has_many :seller_carbon_code_assignments, dependent: :nullify
  has_many :sales_daily_reports, dependent: :destroy
  belongs_to :lead, class_name: 'SalesUser', optional: true
  has_many :team_members, class_name: 'SalesUser', foreign_key: 'lead_id', dependent: :nullify, inverse_of: :lead

  has_secure_password
  has_many :password_otps, as: :otpable, dependent: :destroy
  validates :email, presence: true, uniqueness: true
  validates :phone_number, length: { is: 10 },
            format: { with: /\A\d{10}\z/ },
            allow_blank: true
  validates :manager_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :compensation_type, inclusion: { in: %w[commission employed] }, allow_blank: true
  validate :lead_cannot_be_self

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
    'sales'
  end

  def full_sales_dashboard_access?
    is_manager? || compensation_type == 'employed'
  end

  def team_sales_dashboard_access?
    is_lead? || full_sales_dashboard_access?
  end

  def commission_rep?
    compensation_type.to_s.downcase == 'commission'
  end

  def total_onboarded
    seller_carbon_code_assignments.count
  end

  def earned_commission_batches
    (total_onboarded / 10)
  end

  def unpaid_seller_count
    payable = earned_commission_batches * 10
    [payable - (paid_commission_batches.to_i * 10), 0].max
  end

  def commission_status
    due = unpaid_seller_count
    due > 0 ? "DUE — #{due} sellers" : 'Up to date'
  end

  def commission_due?
    unpaid_seller_count > 0
  end

  def record_commission_payment!(batches = 1)
    new_batch_count = [paid_commission_batches.to_i + batches, earned_commission_batches].min
    update!(paid_commission_batches: new_batch_count, last_commission_paid_at: Time.current)
  end

  private

  def lead_cannot_be_self
    return unless lead_id.present? && lead_id == id
    errors.add(:lead_id, "can't be the same user")
  end
end
