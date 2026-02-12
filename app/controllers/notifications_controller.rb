class NotificationsController < ApplicationController
  before_action :authenticate_request!

  # GET /api/notifications
  def index
    notifications = Notification.where(recipient: @current_user)
                                .order(created_at: :desc)
                                .page(params[:page])
                                .per(params[:per_page] || 20)
    
    render json: {
      notifications: notifications,
      meta: {
        current_page: notifications.current_page,
        total_pages: notifications.total_pages,
        total_count: notifications.total_count,
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
