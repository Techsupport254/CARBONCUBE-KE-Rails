class EmailCommunicationLog < ApplicationRecord
  belongs_to :seller
  
  validates :seller_id, uniqueness: { scope: :email_type }
  validates :email_type, presence: true
  
  scope :sent_successfully, -> { where(sent_successfully: true) }
  scope :for_type, ->(type) { where(email_type: type) }
  
  def self.mark_as_sent(seller, email_type, message_id = nil)
    log = find_or_initialize_by(
      seller_id: seller.id,
      email_type: email_type
    )
    log.message_id = message_id
    log.sent_successfully = true
    log.sent_at = Time.current
    log.save!
  end
  
  def self.already_sent?(seller, email_type)
    exists?(seller_id: seller.id, email_type: email_type, sent_successfully: true)
  end
end
