class SalesUser < ApplicationRecord
  has_many :carbon_codes, as: :associable, dependent: :nullify
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

  private

  def lead_cannot_be_self
    return unless lead_id.present? && lead_id == id
    errors.add(:lead_id, "can't be the same user")
  end
end
