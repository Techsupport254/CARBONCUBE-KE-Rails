class Admin::ConversationsController < ApplicationController
  before_action :authenticate_admin
  before_action :set_conversation, only: [:show]

  # GET /admin/conversations
  def index
    @conversations = Conversation
      .includes(:admin, :buyer, :seller)
      .where(admin_id: current_admin.id)
    
    render json: @conversations, each_serializer: ConversationSerializer
  end

  # GET /admin/conversations/:id
  def show
    render json: @conversation, serializer: ConversationSerializer
  end

  # POST /admin/conversations
  def create
    @conversation = Conversation.new(conversation_params)
    @conversation.admin = current_admin

    if @conversation.save
      render json: @conversation, serializer: ConversationSerializer, status: :created
    else
      render json: { errors: @conversation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /admin/conversations/unread_count
  def unread_count
    # Get all conversations for the current admin
    conversations = Conversation.where(admin_id: current_admin.id)
    
    # Count unread messages (messages not sent by admin and not read)
    unread_count = conversations.joins(:messages)
                               .where(messages: { sender_type: ['Buyer', 'Seller'] })
                               .where(messages: { status: [nil, Message::STATUS_SENT] })
                               .count
    
    render json: { count: unread_count }
  end

  private

  def conversation_params
    params.require(:conversation).permit(:buyer_id, :seller_id)
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
    @conversation = Conversation.includes(:admin, :buyer, :seller, messages: :sender).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Conversation not found" }, status: :not_found
  end
end
