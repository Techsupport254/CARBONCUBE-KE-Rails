class Admin::MessagesController < ApplicationController
  before_action :authenticate_admin
  before_action :set_conversation

  # GET /admin/conversations/:conversation_id/messages
  def index
    is_buyer_seller = @conversation.buyer_id.present? && @conversation.seller_id.present?
    is_seller_to_seller = @conversation.seller_id.present? && @conversation.inquirer_seller_id.present?
    is_support_thread = @conversation.buyer_id.nil? && (@conversation.admin_id.present? || @conversation.is_whatsapp?)
    is_buyer_support = @conversation.seller_id.nil? && @conversation.buyer_id.present? && @conversation.admin_id.present?

    related_conv_ids = [@conversation.id]

    if is_buyer_seller
      buyer_seller_convs = Conversation.where(buyer_id: @conversation.buyer_id, seller_id: @conversation.seller_id).pluck(:id)
      related_conv_ids.concat(buyer_seller_convs)
    elsif is_seller_to_seller
      s2s_convs = Conversation.where(
        "(seller_id = ? AND inquirer_seller_id = ?) OR (seller_id = ? AND inquirer_seller_id = ?)",
        @conversation.seller_id, @conversation.inquirer_seller_id, @conversation.inquirer_seller_id, @conversation.seller_id
      ).pluck(:id)
      related_conv_ids.concat(s2s_convs)
    elsif is_support_thread
      admin_seller_convs = Conversation.where(seller_id: @conversation.seller_id, buyer_id: nil)
                                      .where("admin_id IS NOT NULL OR is_whatsapp = true")
                                      .pluck(:id)
      related_conv_ids.concat(admin_seller_convs)
    elsif is_buyer_support
      admin_buyer_convs = Conversation.where(buyer_id: @conversation.buyer_id, seller_id: nil)
                                     .where.not(admin_id: nil)
                                     .pluck(:id)
      related_conv_ids.concat(admin_buyer_convs)
    end
    
    # Get all messages from these conversations
    all_messages = Message.where(conversation_id: related_conv_ids.uniq).order(created_at: :asc)
    
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
