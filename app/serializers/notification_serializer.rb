# app/serializers/notification_serializer.rb
class NotificationSerializer < ActiveModel::Serializer
  attributes :id, :notifiable_type, :notifiable_id, :order_id, :status, :created_at, :updated_at

  # Optionally, if `notifiable` is associated with other models (like `Admin`), you can include it:
  belongs_to :notifiable, polymorphic: true
end
