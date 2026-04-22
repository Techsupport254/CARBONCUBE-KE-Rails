# app/serializers/message_serializer.rb
class MessageSerializer < ActiveModel::Serializer
  attributes :id, :conversation_id, :sender_id, :sender_type, :content, :created_at, :updated_at

  def content
    strip_markdown(object.content)
  end

  belongs_to :sender, polymorphic: true

  private

  def strip_markdown(text)
    return "" if text.blank?
    text.to_s
      .gsub(/^#+\s+/, '')
      .gsub(/\*\*(.*?)\*\*/, '\1')
      .gsub(/\*(.*?)\*/, '\1')
      .gsub(/__(.*?)__/, '\1')
      .gsub(/_(.*?)_/, '\1')
      .gsub(/\[(.*?)\]\(.*?\)/, '\1')
      .gsub(/`+(.*?)`+/, '\1')
      .gsub(/^\s*[-*+]\s+/, '')
  end
end
