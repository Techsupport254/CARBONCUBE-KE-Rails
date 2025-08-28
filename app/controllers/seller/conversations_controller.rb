class Seller::ConversationsController < ApplicationController
  before_action :authenticate_seller

  def index
    # Fetch ONLY conversations where current seller is the seller
    @conversations = Conversation.where(seller_id: current_seller.id)
                                .includes(:admin, :buyer, :ad, :messages)
                                .order(updated_at: :desc)
    
    # Simple JSON without complex includes to avoid method errors
    conversations_data = @conversations.map do |conversation|
      {
        id: conversation.id,
        seller_id: conversation.seller_id, # Include this to verify
        created_at: conversation.created_at,
        updated_at: conversation.updated_at,
        admin: conversation.admin,
        buyer: conversation.buyer,
        ad: conversation.ad,
        messages_count: conversation.messages.count,
        last_message: conversation.messages.last&.content
      }
    end
    
    render json: conversations_data
  end

  def show
    @conversation = Conversation.find_by(id: params[:id], seller_id: current_seller.id)
    
    if @conversation
      render json: @conversation
    else
      render json: { error: 'Conversation not found' }, status: :not_found
    end
  end

  def create
    @current_user = current_seller
    
    # Find existing conversation or create new one
    @conversation = Conversation.find_or_create_by(
      seller_id: @current_user.id,
      buyer_id: params[:buyer_id],
      ad_id: params[:ad_id]
    ) do |conv|
      conv.admin_id = params[:admin_id] if params[:admin_id].present?
    end

    # Create the message
    message = @conversation.messages.create!(
      content: params[:content],
      sender: @current_user
    )

    # Return the conversation with the new message
    render json: {
      conversation_id: @conversation.id,
      message: {
        id: message.id,
        content: message.content,
        created_at: message.created_at,
        sender_type: message.sender.class.name,
        sender_id: message.sender.id
      }
    }, status: :created
  end

  def update
    @conversation = Conversation.find_by(id: params[:id], seller_id: current_seller.id)
    
    unless @conversation
      render json: { error: 'Conversation not found' }, status: :not_found
      return
    end

    # Add a new message to the conversation
    message = @conversation.messages.create!(
      content: params[:content],
      sender: current_seller
    )

    render json: {
      conversation_id: @conversation.id,
      message: {
        id: message.id,
        content: message.content,
        created_at: message.created_at,
        sender_type: message.sender.class.name,
        sender_id: message.sender.id
      }
    }, status: :created
  end

  private

  def authenticate_seller
    @current_user = SellerAuthorizeApiRequest.new(request.headers).result
    
    if @current_user.nil?
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end