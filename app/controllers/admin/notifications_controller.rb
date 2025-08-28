class Admin::NotificationsController < ApplicationController
  before_action :authenticate_admin

  def index
    notifications = current_admin.notifications.order(created_at: :desc)
    render json: notifications
  end

  def create
    notification = Notification.create!(notification_params)
    NotificationsChannel.broadcast_to(
      current_admin,
      notification: notification.as_json
    )
    head :ok
  end

  private

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def notification_params
    params.require(:notification).permit(:order_id, :status)
          .merge(notifiable: @current_user)
  end

  def current_admin
    @current_user
  end
end
