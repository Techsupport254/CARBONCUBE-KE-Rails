class WhatsappProductSession < ApplicationRecord
  belongs_to :seller
  
  validates :phone_number, presence: true
  validates :status, presence: true
  validates :step, presence: true, numericality: { only_integer: true, greater_than: 0 }
  
  serialize :product_data, coder: JSON
  
  scope :active, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :for_phone, ->(phone) { where(phone_number: phone) }
  
  STATUS_PENDING = 'pending'
  STATUS_COMPLETED = 'completed'
  STATUS_CANCELLED = 'cancelled'
  
  STEPS = {
    1 => 'title',
    2 => 'description',
    3 => 'price',
    4 => 'category',
    5 => 'brand',
    6 => 'condition',
    7 => 'images',
    8 => 'confirm'
  }.freeze
  
  def current_step_name
    STEPS[step]
  end
  
  def advance_step!
    update(step: step + 1, last_message_at: Time.current)
  end
  
  def complete!
    update(status: STATUS_COMPLETED, last_message_at: Time.current)
  end
  
  def cancel!
    update(status: STATUS_CANCELLED, last_message_at: Time.current)
  end
  
  def update_product_data(key, value)
    current_data = product_data || {}
    current_data[key] = value
    update(product_data: current_data, last_message_at: Time.current)
  end
  
  def get_product_data(key)
    product_data&.dig(key)
  end
  
  def self.find_or_create_session(seller, phone_number)
    existing = active.for_phone(phone_number).where(seller_id: seller.id).first
    if existing
      existing.update(last_message_at: Time.current)
      existing
    else
      create(seller: seller, phone_number: phone_number, status: STATUS_PENDING, step: 1, last_message_at: Time.current)
    end
  end
end
