class Buyer::ConversationsController < ApplicationController
  before_action :authenticate_buyer

  def index
    # Fetch ONLY conversations where current buyer is the buyer
    @conversations = Conversation.where(buyer_id: current_buyer.id)
                                .includes(:admin, :seller, :ad, :messages)
                                .order(updated_at: :desc)
    
    # Simple JSON without complex includes to avoid method errors
    conversations_data = @conversations.map do |conversation|
      {
        id: conversation.id,
        buyer_id: conversation.buyer_id, # Include this to verify
        created_at: conversation.created_at,
        updated_at: conversation.updated_at,
        admin: conversation.admin,
        seller: conversation.seller,
        ad: conversation.ad,
        messages_count: conversation.messages.count,
        last_message: conversation.messages.last&.content
      }
    end
    
    render json: conversations_data
  end

  def show
    @conversation = Conversation.find_by(id: params[:id], buyer_id: current_buyer.id)
    
    if @conversation
      render json: @conversation
    else
      render json: { error: 'Conversation not found' }, status: :not_found
    end
  end

  def create
    @current_user = current_buyer
    
    # Find existing conversation or create new one
    @conversation = Conversation.find_or_create_by(
      buyer_id: @current_user.id,
      seller_id: params[:seller_id],
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
    @conversation = Conversation.find_by(id: params[:id], buyer_id: current_buyer.id)
    
    unless @conversation
      render json: { error: 'Conversation not found' }, status: :not_found
      return
    end

    # Add a new message to the conversation
    message = @conversation.messages.create!(
      content: params[:content],
      sender: current_buyer
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

  def authenticate_buyer
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
    
    if @current_user.nil?
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end