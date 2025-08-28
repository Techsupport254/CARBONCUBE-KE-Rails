class Admin::MessagesController < ApplicationController
  before_action :authenticate_admin
  before_action :set_conversation

  # GET /admin/conversations/:conversation_id/messages
  def index
    @messages = @conversation.messages.includes(:sender).order(created_at: :asc)
    render json: @messages, each_serializer: MessageSerializer
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
    params.require(:message).permit(:content)
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
