# app/serializers/message_serializer.rb
class MessageSerializer < ActiveModel::Serializer
  attributes :id, :conversation_id, :sender_id, :sender_type, :content, :created_at, :updated_at

  belongs_to :sender, polymorphic: true
end
