class NotificationsController < ApplicationController
  before_action :authenticate_request

  # GET /notifications
  def index
    per_page = (params[:per_page] || 20).to_i
    notifications = Notification.where(recipient: @current_user)
                                .order(created_at: :desc)
                                .limit(per_page)
    
    render json: {
      notifications: notifications,
      meta: {
        total_count: Notification.where(recipient: @current_user).count,
        unread_count: Notification.where(recipient: @current_user, read_at: nil).count
      }
    }
  end

  # POST /api/notifications/:id/read
  def mark_as_read
    notification = Notification.find_by(id: params[:id], recipient: @current_user)
    
    if notification
      notification.update(read_at: Time.current)
      render json: { message: 'Notification marked as read' }
    else
      render json: { error: 'Notification not found' }, status: :not_found
    end
  end

  # POST /api/notifications/read_all
  def mark_all_as_read
    Notification.where(recipient: @current_user, read_at: nil).update_all(read_at: Time.current)
    render json: { message: 'All notifications marked as read' }
  end
end
