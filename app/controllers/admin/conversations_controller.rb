class Admin::ConversationsController < ApplicationController
  before_action :authenticate_admin
  before_action :set_conversation, only: [:show]

  # GET /admin/conversations
  def index
    # Only return conversations that have at least one message
    @conversations = Conversation
      .active_participants
      .includes(:admin, :buyer, :seller, :messages)
      .where("conversations.admin_id = ?", current_admin.id)
      .joins(:messages)
      .distinct
      .order("conversations.updated_at DESC")
    
    render json: @conversations, each_serializer: ConversationSerializer
  end

  # GET /admin/conversations/:id
  def show
    render json: @conversation, serializer: ConversationSerializer
  end

  # POST /admin/conversations
  def create
    # Handle race conditions where multiple requests try to create the same conversation
    begin
      # Use the model method that handles race conditions properly
      @conversation = Conversation.find_or_create_conversation!(
        admin_id: current_admin.id,
        seller_id: conversation_params[:seller_id],
        buyer_id: conversation_params[:buyer_id],
        inquirer_seller_id: nil,
        ad_id: conversation_params[:ad_id]
      )
      
      render json: @conversation, serializer: ConversationSerializer, status: :created
    rescue => e
      Rails.logger.error "Error in conversation creation: #{e.class.name} - #{e.message}" if defined?(Rails.logger)
      render json: { errors: ["Failed to create conversation: #{e.message}"] }, status: :unprocessable_entity
    end
  end

  # GET /admin/conversations/unread_count
  def unread_count
    # Get all conversations for the current admin
    conversations = Conversation.where(admin_id: current_admin.id)
                                .active_participants
    
    # Calculate total unread count by iterating through conversations
    # This avoids duplicate counting issues with joins
    # Use read_at: nil for consistency with other controllers
    total_unread = 0
    conversations.each do |conversation|
      unread_count = conversation.messages
                                .where(sender_type: ['Seller', 'Buyer', 'Purchaser'])
                                .where(read_at: nil)
                                .count
      total_unread += unread_count
    end
    
    render json: { count: total_unread }
  end

  private

  def conversation_params
    params.require(:conversation).permit(:buyer_id, :seller_id, :ad_id)
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

  def set_conversation
    @conversation = Conversation.active_participants
                                .includes(:admin, :buyer, :seller, messages: :sender)
                                .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Conversation not found" }, status: :not_found
  end
end
