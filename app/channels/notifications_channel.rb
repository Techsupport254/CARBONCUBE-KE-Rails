class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    if params[:admin_id]
      stream_for Admin.find(params[:admin_id])
    elsif params[:seller_id]
      stream_for Seller.find(params[:seller_id])
    elsif params[:buyer_id]
      stream_for Buyer.find(params[:buyer_id])
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
