class Conversation < ApplicationRecord
  after_create :associate_guest_clicks_with_buyer
  belongs_to :admin, class_name: 'Admin', foreign_key: 'admin_id', optional: true
  belongs_to :buyer, class_name: 'Buyer', foreign_key: 'buyer_id', optional: true
  belongs_to :seller, class_name: 'Seller', foreign_key: 'seller_id', optional: true
  belongs_to :inquirer_seller, class_name: 'Seller', foreign_key: 'inquirer_seller_id', optional: true
  belongs_to :ad, optional: true

  has_many :messages, dependent: :destroy

  # Find or create conversation with race condition handling
  # Uses database-level conflict resolution for better reliability
  def self.find_or_create_conversation!(attributes)
    # Try to find first
    conversation = find_by_conversation_attributes(attributes)
    if conversation
      Rails.logger.info("Found existing conversation: #{conversation.id}") if defined?(Rails.logger)
      return conversation
    end

    # Try to create with ON CONFLICT handling
    begin
      conversation = create!(attributes)
      Rails.logger.info("Created new conversation: #{conversation.id}") if defined?(Rails.logger)
      return conversation
    rescue ActiveRecord::RecordNotUnique => e
      # Check if it's a primary key violation (shouldn't happen with UUIDs, but handle it)
      if e.message.include?('conversations_pkey') || (e.message.include?('duplicate key value') && e.message.include?('Key (id)='))
        # With UUIDs, this shouldn't happen, but if it does, retry once
        Rails.logger.error("Primary key violation with UUID - this shouldn't happen: #{e.message}") if defined?(Rails.logger)
        # Try creating again (UUID should be unique)
        begin
          conversation = create!(attributes)
          Rails.logger.info("Created conversation after retry: #{conversation.id}") if defined?(Rails.logger)
          return conversation
        rescue => retry_e
          Rails.logger.error("Still getting primary key violation: #{retry_e.message}") if defined?(Rails.logger)
          raise
        end
      end
      
      # If we get here, it's a unique index violation (race condition), not a primary key issue
      # Another request created it - find it now
      Rails.logger.warn("Race condition detected: #{e.message}. Attributes: #{attributes.inspect}") if defined?(Rails.logger)
      
      # Use a transaction with retries to ensure we see the committed data
      max_retries = 10  # Increased retries
      retry_count = 0
      
      while retry_count < max_retries
        # Use a fresh connection to avoid transaction isolation issues
        # Also try querying directly with SQL to bypass any AR caching
        ActiveRecord::Base.connection_pool.with_connection do |conn|
          # Try AR query first
          conversation = find_by_conversation_attributes(attributes)
          if conversation
            Rails.logger.info("Found conversation after #{retry_count} retries: #{conversation.id}") if defined?(Rails.logger)
            return conversation
          end
          
          # Also try raw SQL query to ensure we're not missing anything
          # Use ActiveRecord's exec_query for better compatibility
          sql, values = build_find_sql(attributes)
          result = conn.exec_query(sql, 'SQL', values)
          if result.any?
            conversation_id = result.first['id']
            conversation = find(conversation_id)
            Rails.logger.info("Found conversation via SQL after #{retry_count} retries: #{conversation.id}") if defined?(Rails.logger)
            return conversation
          end
        end
        
        # Small delay for transaction to commit (increasing delay)
        sleep(0.05 * (retry_count + 1)) if Rails.env.development?
        retry_count += 1
      end
      
      # Final attempt with longer delay
      sleep(0.2) if Rails.env.development?
      conversation = find_by_conversation_attributes(attributes)
      
      unless conversation
        # Log the failure with details
        Rails.logger.error("Failed to find conversation after #{max_retries} retries. Attributes: #{attributes.inspect}") if defined?(Rails.logger)
        # Try one more time with raw SQL
        sql, values = build_find_sql(attributes)
        result = ActiveRecord::Base.connection.exec_query(sql, 'SQL', values)
        if result.any?
          conversation_id = result.first['id']
          conversation = find(conversation_id)
          Rails.logger.info("Found conversation in final SQL attempt: #{conversation.id}") if defined?(Rails.logger)
          return conversation
        end
        
        # Last resort: try to create again (maybe the other transaction rolled back)
        begin
          conversation = create!(attributes)
          Rails.logger.info("Successfully created conversation on retry: #{conversation.id}") if defined?(Rails.logger)
          return conversation
        rescue ActiveRecord::RecordNotUnique => retry_e
          # Still can't create or find - this is a real problem
          Rails.logger.error("CRITICAL: Cannot find or create conversation. Unique constraint: #{retry_e.message}. Attributes: #{attributes.inspect}") if defined?(Rails.logger)
          
          # One absolute final attempt to find it
          sleep(0.5) if Rails.env.development?
          conversation = find_by_conversation_attributes(attributes)
          return conversation if conversation
          
          # If we still can't find it, there's a deeper issue - return nil and let controller handle it
          Rails.logger.error("FATAL: Could not find conversation after all retries. This suggests a data integrity issue.") if defined?(Rails.logger)
          return nil
        end
      end
      
      conversation
    end
  end
  
  # Build raw SQL query for finding conversations (bypasses AR caching)
  def self.build_find_sql(attrs)
    conditions = []
    values = []
    param_index = 1
    
    # Handle ad_id
    if attrs[:ad_id].nil?
      conditions << "ad_id IS NULL"
    else
      conditions << "ad_id = $#{param_index}"
      values << attrs[:ad_id]
      param_index += 1
    end
    
    # Handle buyer_id
    if attrs[:buyer_id].nil?
      conditions << "buyer_id IS NULL"
    else
      conditions << "buyer_id = $#{param_index}::uuid"
      values << attrs[:buyer_id].to_s
      param_index += 1
    end
    
    # Handle seller_id
    if attrs[:seller_id].nil?
      conditions << "seller_id IS NULL"
    else
      conditions << "seller_id = $#{param_index}::uuid"
      values << attrs[:seller_id].to_s
      param_index += 1
    end
    
    # Handle inquirer_seller_id
    if attrs[:inquirer_seller_id].nil?
      conditions << "inquirer_seller_id IS NULL"
    else
      conditions << "inquirer_seller_id = $#{param_index}::uuid"
      values << attrs[:inquirer_seller_id].to_s
      param_index += 1
    end
    
    # Handle admin_id
    if attrs[:admin_id].nil?
      conditions << "admin_id IS NULL"
    else
      conditions << "admin_id = $#{param_index}::uuid"
      values << attrs[:admin_id].to_s
      param_index += 1
    end
    
    sql = "SELECT id FROM conversations WHERE #{conditions.join(' AND ')} LIMIT 1"
    [sql, values]
  end

  # Find conversation by exact attributes (handles NULLs correctly)
  def self.find_by_conversation_attributes(attrs)
    # Start with base query - handle ad_id NULL explicitly
    if attrs[:ad_id].nil?
      query = where(ad_id: nil)
    else
      query = where(ad_id: attrs[:ad_id])
    end
    
    # Handle NULL values explicitly for all participant fields
    # PostgreSQL unique indexes treat NULLs specially, so we must match them exactly
    if attrs[:buyer_id].nil?
      query = query.where(buyer_id: nil)
    else
      query = query.where(buyer_id: attrs[:buyer_id])
    end
    
    if attrs[:seller_id].nil?
      query = query.where(seller_id: nil)
    else
      query = query.where(seller_id: attrs[:seller_id])
    end
    
    if attrs[:inquirer_seller_id].nil?
      query = query.where(inquirer_seller_id: nil)
    else
      query = query.where(inquirer_seller_id: attrs[:inquirer_seller_id])
    end
    
    if attrs[:admin_id].nil?
      query = query.where(admin_id: nil)
    else
      query = query.where(admin_id: attrs[:admin_id])
    end
    
    query.first
  end

  # Scopes to filter conversations with active (not deleted/blocked) participants
  # Using subqueries for better performance - only includes conversations where all participants are active
  scope :active_participants, -> {
    active_buyer_ids = Buyer.active.select(:id)
    active_seller_ids = Seller.active.select(:id)
    
    where(
      "(conversations.buyer_id IS NULL OR conversations.buyer_id IN (?)) AND " \
      "(conversations.seller_id IS NULL OR conversations.seller_id IN (?)) AND " \
      "(conversations.inquirer_seller_id IS NULL OR conversations.inquirer_seller_id IN (?))",
      active_buyer_ids,
      active_seller_ids,
      active_seller_ids
    )
  }

  # Validation for participant presence
  validate :at_least_one_participant_present
  validate :buyer_exists_if_present
  validate :seller_exists_if_present
  validate :admin_exists_if_present
  validates :ad_id, uniqueness: { 
    scope: [:buyer_id, :seller_id, :inquirer_seller_id], 
    message: "conversation already exists for this ad with these participants" 
  }

  # Associate guest click events with buyer when they send a message
  # This ensures that clicks made before authentication are properly attributed
  def associate_guest_clicks_with_buyer
    return unless buyer_id.present? && ad_id.present?
    
    # Find guest click events for this ad that happened before the conversation was created
    # Look for clicks within a reasonable time window (e.g., 24 hours before conversation)
    time_window = created_at - 24.hours
    
    guest_clicks = ClickEvent
      .where(ad_id: ad_id)
      .where(buyer_id: nil)
      .where('created_at >= ? AND created_at <= ?', time_window, created_at)
      .where.not(id: ClickEvent.where(buyer_id: buyer_id).select(:id)) # Don't update clicks already associated
    
    if guest_clicks.any?
      updated_count = guest_clicks.update_all(buyer_id: buyer_id)
      Rails.logger.info "Associated #{updated_count} guest click events with buyer #{buyer_id} for ad #{ad_id}" if defined?(Rails.logger)
    end
  rescue => e
    # Don't fail conversation creation if this fails
    Rails.logger.error "Failed to associate guest clicks: #{e.message}" if defined?(Rails.logger)
  end

  private

  def at_least_one_participant_present
    if admin_id.blank? && buyer_id.blank? && seller_id.blank? && inquirer_seller_id.blank?
      errors.add(:base, 'Conversation must have at least one participant (admin, buyer, seller, or inquirer_seller)')
    end
  end

  def buyer_exists_if_present
    if buyer_id.present? && !Buyer.active.exists?(buyer_id)
      errors.add(:buyer_id, 'Buyer does not exist or is inactive')
    end
  end

  def seller_exists_if_present
    if seller_id.present? && !Seller.active.exists?(seller_id)
      errors.add(:seller_id, 'Seller does not exist or is inactive')
    end
    if inquirer_seller_id.present? && !Seller.active.exists?(inquirer_seller_id)
      errors.add(:inquirer_seller_id, 'Inquirer seller does not exist or is inactive')
    end
  end

  def admin_exists_if_present
    if admin_id.present? && !Admin.exists?(admin_id)
      errors.add(:admin_id, 'Admin does not exist')
    end
  end
end

