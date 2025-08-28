class Buyer::MessagesController < ApplicationController
  before_action :authenticate_buyer
  before_action :set_conversation

  def index
    @messages = @conversation.messages.includes(:sender).order(:created_at)
    render json: @messages.as_json(include: :sender)
  end

  def create
    @message = @conversation.messages.build(message_params)
    @message.sender = current_buyer

    if @message.save
      render json: @message.as_json(include: :sender), status: :created
    else
      render json: @message.errors, status: :unprocessable_entity
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find_by(id: params[:conversation_id], buyer_id: current_buyer.id)
    
    unless @conversation
      render json: { error: 'Conversation not found or unauthorized' }, status: :not_found
    end
  end

  def message_params
    params.require(:message).permit(:content)
  end

  def authenticate_buyer
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
    render json: { error: 'Not Authorized' }, status: :unauthorized unless @current_user&.is_a?(Buyer)
  end

  def current_buyer
    @current_user
  end
end