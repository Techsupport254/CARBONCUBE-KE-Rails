require 'dry-validation'

# Base validator for WebSocket messages
class WebSocketMessageValidator < Dry::Validation::Contract
  # Common validation rules
  def self.timestamp_format
    ->(value) { Time.parse(value.to_s) rescue false }
  end
  
  def self.non_empty_string
    ->(value) { value.is_a?(String) && !value.strip.empty? }
  end
end

# Validator for conversation messages
class ConversationMessageValidator < WebSocketMessageValidator
  params do
    required(:conversation_id).filled(:integer)
    required(:content).filled(:string)
    required(:sender_type).filled(:string, included_in?: %w[Buyer Seller Admin])
    required(:sender_id).filled(:integer)
    optional(:ad_id).maybe(:integer)
    optional(:product_context).maybe(:hash)
    optional(:message_type).filled(:string, included_in?: %w[text image file])
  end
  
  rule(:content) do
    if value.length > 5000
      key.failure('content cannot exceed 5000 characters')
    end
  end
  
  rule(:content) do
    # Basic content sanitization check
    if value.match?(/javascript:|<script|onclick|onerror/i)
      key.failure('content contains potentially malicious code')
    end
  end
end

# Validator for presence updates
class PresenceUpdateValidator < WebSocketMessageValidator
  params do
    required(:type).filled(:string, included_in?: %w[typing_start typing_stop message_read message_delivered online offline])
    optional(:conversation_id).maybe(:integer)
    optional(:message_id).maybe(:integer)
    optional(:user_id).maybe(:integer)
    optional(:timestamp).maybe(:string)
  end
  
  rule(:timestamp) do
    if key? && value
      unless WebSocketMessageValidator.timestamp_format.call(value)
        key.failure('must be a valid timestamp')
      end
    end
  end
end

# Validator for notification messages
class NotificationMessageValidator < WebSocketMessageValidator
  params do
    required(:type).filled(:string, included_in?: %w[order_update payment_confirmation new_message system_alert])
    required(:title).filled(:string)
    required(:message).filled(:string)
    optional(:action_url).maybe(:string)
    optional(:priority).filled(:string, included_in?: %w[low medium high urgent])
    optional(:expires_at).maybe(:string)
  end
  
  rule(:title) do
    if value.length > 100
      key.failure('title cannot exceed 100 characters')
    end
  end
  
  rule(:message) do
    if value.length > 500
      key.failure('message cannot exceed 500 characters')
    end
  end
  
  rule(:expires_at) do
    if key? && value
      begin
        expires_time = Time.parse(value)
        if expires_time <= Time.current
          key.failure('expires_at must be in the future')
        end
      rescue ArgumentError
        key.failure('must be a valid timestamp')
      end
    end
  end
end
