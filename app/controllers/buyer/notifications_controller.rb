class Buyer::NotificationsController < ApplicationController
  before_action :authenticate_buyer

  def index
    notifications = current_buyer.notifications.order(created_at: :desc)
    render json: notifications
  end

  def create
    notification = Notification.create!(notification_params)
    NotificationsChannel.broadcast_to(
      current_buyer,
      notification: notification.as_json
    )
    head :ok
  end

  private

  def authenticate_buyer
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Buyer)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def notification_params
    params.require(:notification).permit(:order_id, :status, :issue)
          .merge(notifiable: @current_user)
  end

  def current_buyer
    @current_user
  end
end
