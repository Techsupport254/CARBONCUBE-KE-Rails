class Sales::ConversationsController < ApplicationController
  before_action :authenticate_sales_user

  def index
    # Fetch conversations where current sales user is involved
    @conversations = Conversation.where(admin_id: @current_user.id)
                                .active_participants
                                .includes(:admin, :seller, :buyer, :inquirer_seller, :ad, :messages, ad: [:category, :subcategory])
                                .order(updated_at: :desc)
    
    # Group conversations by unique participant pairs to avoid merging different threads
    grouped_conversations = @conversations.group_by do |c|
      [c.seller_id, c.buyer_id, c.inquirer_seller_id, c.admin_id]
    end
    
    # For each group, get the most recent conversation and combine all messages
    conversations_data = grouped_conversations.map do |participant_key, conversations|
      # Get the most recent conversation for this group
      most_recent_conversation = conversations.max_by(&:updated_at)
      
      # Get all messages from all conversations in this group
      all_messages = conversations.flat_map(&:messages).sort_by(&:created_at)
      last_message = all_messages.last
      
      # Get the most recent ad context
      current_ad = most_recent_conversation.ad
      
      # Ensure admin info is correctly fetched even if it's a SalesUser/MarketingUser
      admin_user = most_recent_conversation.admin || 
                   SalesUser.find_by(id: most_recent_conversation.admin_id) ||
                   MarketingUser.find_by(id: most_recent_conversation.admin_id)

      {
        id: most_recent_conversation.id,
        seller_id: most_recent_conversation.seller_id,
        buyer_id: most_recent_conversation.buyer_id,
        admin_id: most_recent_conversation.admin_id,
        created_at: most_recent_conversation.created_at,
        updated_at: most_recent_conversation.updated_at,
        admin: admin_user ? {
          id: admin_user.id,
          fullname: admin_user.fullname,
          username: admin_user.try(:username),
          email: admin_user.email,
          profile_picture: nil
        } : nil,
        seller: most_recent_conversation.seller,
        buyer: most_recent_conversation.buyer,
        inquirer_seller: most_recent_conversation.inquirer_seller,
        ad: current_ad,
        messages_count: all_messages.count,
        last_message: last_message&.content,
        last_message_time: last_message&.created_at,
        all_conversation_ids: conversations.map(&:id)
      }
    end
    
    render json: conversations_data
  end

  def show
    @conversation = Conversation.active_participants
                                .find_by(id: params[:id], admin_id: @current_user.id)
    
    if @conversation
      # Get all conversations with the same seller
      related_conv_ids = [@conversation.id]
      
      if @conversation.seller_id.present?
        # Find all Admin-Seller support conversations (no buyer) for this seller
        admin_seller_convs = Conversation.where(seller_id: @conversation.seller_id)
                                        .where(buyer_id: nil)
                                        .pluck(:id)
        related_conv_ids.concat(admin_seller_convs)
      end
      
      # Get all messages from all conversations in this set
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
          product_context: message.product_context
        }
        
        # Add ad information if the message has an ad_id
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
        conversation: @conversation.as_json(include: [:admin, :buyer, :seller, :inquirer_seller]),
        messages: messages_with_ads,
        total_messages: messages_with_ads.count
      }
    else
      render json: { error: 'Conversation not found' }, status: :not_found
    end
  end

  def create
    # If seller_id is not provided but ad_id is, get seller_id from the ad
    seller_id = params[:seller_id]
    if params[:seller_id].blank? && params[:ad_id].present?
      ad = Ad.find(params[:ad_id])
      seller_id = ad.seller_id if ad
    end
    
    # Find existing conversation or create new one
    # Handle race conditions where multiple requests try to create the same conversation
    begin
      # Use the model method that handles race conditions properly
      @conversation = Conversation.find_or_create_conversation!(
        admin_id: @current_user.id,
        seller_id: seller_id,
        buyer_id: params[:buyer_id],
        inquirer_seller_id: nil,
        ad_id: params[:ad_id]
      )
    rescue => e
      Rails.logger.error "Error in conversation creation: #{e.class.name} - #{e.message}" if defined?(Rails.logger)
      render json: { error: "Failed to create conversation: #{e.message}" }, status: :unprocessable_entity
      return
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
    @conversation = Conversation.find_by(id: params[:id], admin_id: @current_user.id)
    
    unless @conversation
      render json: { error: 'Conversation not found' }, status: :not_found
      return
    end

    # Add a new message to the conversation
    message = @conversation.messages.create!(
      content: params[:content],
      sender: @current_user
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

  # GET /sales/conversations/unread_counts
  def unread_counts
    # Get all conversations for the current sales user with unread message counts
    conversations = Conversation.where(admin_id: @current_user.id)
                                .active_participants
    
    unread_counts = conversations.map do |conversation|
      unread_count = conversation.messages
                                .where(sender_type: ['Seller', 'Buyer', 'Purchaser'])
                                .where(read_at: nil)
                                .count
      
      {
        conversation_id: conversation.id,
        unread_count: unread_count
      }
    end
    
    # Count conversations with unread messages
    conversations_with_unread = unread_counts.count { |item| item[:unread_count] > 0 }
    
    render json: { 
      unread_counts: unread_counts,
      conversations_with_unread: conversations_with_unread
    }
  end

  # GET /sales/conversations/unread_count
  def unread_count
    # Get all conversations for the current sales user
    conversations = Conversation.where(admin_id: @current_user.id)
                                .active_participants
    
    # Calculate total unread count by iterating through conversations
    # This avoids duplicate counting issues with joins
    total_unread = 0
    conversations.each do |conversation|
      # Count messages from sellers, buyers, and purchasers (not from sales users)
      unread_count = conversation.messages
                                .where(sender_type: ['Seller', 'Buyer', 'Purchaser'])
                                .where(read_at: nil)
                                .count
      total_unread += unread_count
    end
    
    render json: { count: total_unread }
  end

  private

  def authenticate_sales_user
    @current_user = SalesAuthorizeApiRequest.new(request.headers).result
    
    if @current_user.nil?
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
