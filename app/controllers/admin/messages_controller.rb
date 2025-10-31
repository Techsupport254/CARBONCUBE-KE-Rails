class Admin::MessagesController < ApplicationController
  before_action :authenticate_admin
  before_action :set_conversation

  # GET /admin/conversations/:conversation_id/messages
  def index
    # Get all messages from this conversation, including ad info
    all_messages = @conversation.messages.order(created_at: :asc)
    
    # Include ad information for each message
    messages_with_ads = all_messages.map do |message|
      message_data = {
        id: message.id,
        content: message.content,
        created_at: message.created_at,
        sender_type: message.sender_type,
        sender_id: message.sender_id,
        ad_id: message.ad_id,
        product_context: message.product_context,
        status: message.status,
        read_at: message.read_at,
        delivered_at: message.delivered_at
      }
      
      if message.ad_id
        ad = Ad.find_by(id: message.ad_id)
        if ad
          message_data[:ad] = {
            id: ad.id,
            title: ad.title,
            price: ad.price,
            first_media_url: ad.media.first,
            category: ad.category&.name,
            subcategory: ad.subcategory&.name
          }
        end
      end
      
      message_data
    end
    
    render json: {
      messages: messages_with_ads,
      total_messages: messages_with_ads.count
    }
  end

  # POST /admin/conversations/:conversation_id/messages
  def create
    @message = @conversation.messages.build(message_params)
    @message.sender = current_admin
    @message.sender_type = 'Admin'

    if @message.save
      render json: @message, serializer: MessageSerializer, status: :created
    else
      render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Conversation not found" }, status: :not_found
  end

  def message_params
    params.require(:message).permit(:content, :ad_id)
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_admin
    @current_user
  end
end
