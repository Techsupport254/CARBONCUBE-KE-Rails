class Notification < ApplicationRecord
  belongs_to :notifiable, polymorphic: true
  belongs_to :order

  after_create_commit :broadcast_notification

  private

  def broadcast_notification
    if self.buyer_id
      NotificationsChannel.broadcast_to(Buyer.find(self.buyer_id), self)
    elsif self.seller_id
      NotificationsChannel.broadcast_to(Seller.find(self.seller_id), self)
    elsif self.admin_id
      NotificationsChannel.broadcast_to(Admin.find(self.admin_id), self)
    end
  end
end
