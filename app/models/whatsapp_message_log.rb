class WhatsappMessageLog < ApplicationRecord
  belongs_to :seller
  
  validates :seller_id, uniqueness: { scope: :template_name }
  validates :phone_number, :template_name, presence: true
  
  scope :sent_successfully, -> { where(sent_successfully: true) }
  scope :for_template, ->(template) { where(template_name: template) }
  
  def self.mark_as_sent(seller, template_name, phone_number, message_id = nil)
    log = find_or_initialize_by(
      seller_id: seller.id,
      template_name: template_name
    )
    log.phone_number = phone_number
    log.message_id = message_id
    log.sent_successfully = true
    log.sent_at = Time.current
    log.save!
  end
  
  def self.already_sent?(seller, template_name)
    exists?(seller_id: seller.id, template_name: template_name, sent_successfully: true)
  end
end
