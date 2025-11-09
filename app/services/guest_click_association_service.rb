class GuestClickAssociationService
  # Associate guest clicks with a user (buyer or seller)
  def self.associate_clicks_with_user(user, device_hash = nil)
    return unless user.is_a?(Buyer) || user.is_a?(Seller)
    
    if user.is_a?(Buyer)
      associate_clicks_with_buyer(user, device_hash)
    elsif user.is_a?(Seller)
      associate_clicks_with_seller(user, device_hash)
    end
  end
  
  # Associate guest clicks with buyer (sets buyer_id)
  def self.associate_clicks_with_buyer(buyer, device_hash = nil)
    return unless buyer.is_a?(Buyer)
    
    # If device_hash is provided, use it directly
    # Otherwise, try to find the most recent click event for this buyer's email in metadata
    device_hashes_to_check = []
    
    if device_hash.present?
      device_hashes_to_check << device_hash
    else
      # Find device hashes from recent guest clicks that might belong to this buyer
      # Look for clicks with this email in metadata (for OAuth users who clicked before registering)
      recent_guest_clicks = ClickEvent
        .where(buyer_id: nil)
        .where("metadata->>'user_email' = ?", buyer.email.downcase)
        .where('created_at >= ?', buyer.created_at - 7.days) # Within 7 days before registration
        .order(created_at: :desc)
        .limit(50)
      
      device_hashes_to_check.concat(recent_guest_clicks.pluck(Arel.sql("metadata->>'device_hash'")).compact.uniq)
    end
    
    return if device_hashes_to_check.empty?
    
    associated_count = 0
    
    device_hashes_to_check.each do |hash|
      next if hash.blank?
      
      # Find all guest click events with this device hash
      # Look for clicks within a reasonable time window (30 days before account creation)
      time_window_start = buyer.created_at - 30.days
      time_window_end = buyer.created_at + 1.day # Allow 1 day after for edge cases
      
      guest_clicks = ClickEvent
        .where(buyer_id: nil)
        .where("metadata->>'device_hash' = ?", hash)
        .where('created_at >= ? AND created_at <= ?', time_window_start, time_window_end)
        .where.not(id: ClickEvent.where(buyer_id: buyer.id).select(:id)) # Don't update clicks already associated
      
      if guest_clicks.any?
        updated = guest_clicks.update_all(buyer_id: buyer.id)
        associated_count += updated
        Rails.logger.info "Associated #{updated} guest click events with buyer #{buyer.id} using device hash #{hash[0..10]}..." if defined?(Rails.logger)
      end
    end
    
    # Also check for clicks with email in metadata (for cases where device hash wasn't captured)
    if device_hash.blank?
      email_clicks = ClickEvent
        .where(buyer_id: nil)
        .where("LOWER(metadata->>'user_email') = ?", buyer.email.downcase)
        .where('created_at >= ? AND created_at <= ?', buyer.created_at - 30.days, buyer.created_at + 1.day)
        .where.not(id: ClickEvent.where(buyer_id: buyer.id).select(:id))
      
      if email_clicks.any?
        updated = email_clicks.update_all(buyer_id: buyer.id)
        associated_count += updated
        Rails.logger.info "Associated #{updated} guest click events with buyer #{buyer.id} using email match" if defined?(Rails.logger)
      end
    end
    
    Rails.logger.info "Total guest clicks associated with buyer #{buyer.id}: #{associated_count}" if defined?(Rails.logger) && associated_count > 0
    
    associated_count
  rescue => e
    Rails.logger.error "Failed to associate guest clicks with buyer #{buyer.id}: #{e.message}" if defined?(Rails.logger)
    Rails.logger.error e.backtrace.first(10).join("\n") if defined?(Rails.logger)
    0
  end
  
  # Associate guest clicks with seller (updates metadata to include seller_id)
  # Since click_events only has buyer_id, we update metadata to track seller association
  def self.associate_clicks_with_seller(seller, device_hash = nil)
    return unless seller.is_a?(Seller)
    
    # If device_hash is provided, use it directly
    # Otherwise, try to find the most recent click event for this seller's email in metadata
    device_hashes_to_check = []
    
    if device_hash.present?
      device_hashes_to_check << device_hash
    else
      # Find device hashes from recent guest clicks that might belong to this seller
      # Look for clicks with this email in metadata and user_role='seller'
      recent_guest_clicks = ClickEvent
        .where(buyer_id: nil)
        .where("LOWER(metadata->>'user_email') = ?", seller.email.downcase)
        .where("metadata->>'user_role' = ?", 'seller')
        .where('created_at >= ?', seller.created_at - 7.days) # Within 7 days before registration
        .order(created_at: :desc)
        .limit(50)
      
      device_hashes_to_check.concat(recent_guest_clicks.pluck(Arel.sql("metadata->>'device_hash'")).compact.uniq)
    end
    
    associated_count = 0
    
    # Process device hashes
    if device_hashes_to_check.any?
      device_hashes_to_check.each do |hash|
        next if hash.blank?
        
        # Find all guest click events with this device hash
        # Look for clicks within a reasonable time window (30 days before account creation)
        time_window_start = seller.created_at - 30.days
        time_window_end = seller.created_at + 1.day # Allow 1 day after for edge cases
        
        guest_clicks = ClickEvent
          .where(buyer_id: nil)
          .where("metadata->>'device_hash' = ?", hash)
          .where('created_at >= ? AND created_at <= ?', time_window_start, time_window_end)
          .where("(metadata->>'seller_id' IS NULL OR metadata->>'seller_id' != ?)", seller.id.to_s) # Don't update clicks already associated
        
        if guest_clicks.any?
          # Update metadata to include seller_id and ensure user_role is 'seller'
          guest_clicks.find_each do |click|
            metadata = click.metadata || {}
            metadata['seller_id'] = seller.id.to_s
            metadata['user_role'] = 'seller'
            metadata['user_email'] = seller.email
            metadata['user_id'] = seller.id.to_s
            click.update_column(:metadata, metadata)
            associated_count += 1
          end
          Rails.logger.info "Associated #{associated_count} guest click events with seller #{seller.id} using device hash #{hash[0..10]}..." if defined?(Rails.logger)
        end
      end
    end
    
    # Also check for clicks with email in metadata (for cases where device hash wasn't captured)
    if device_hash.blank?
      email_clicks = ClickEvent
        .where(buyer_id: nil)
        .where("LOWER(metadata->>'user_email') = ?", seller.email.downcase)
        .where('created_at >= ? AND created_at <= ?', seller.created_at - 30.days, seller.created_at + 1.day)
        .where("(metadata->>'seller_id' IS NULL OR metadata->>'seller_id' != ?)", seller.id.to_s)
      
      if email_clicks.any?
        email_clicks.find_each do |click|
          metadata = click.metadata || {}
          metadata['seller_id'] = seller.id.to_s
          metadata['user_role'] = 'seller'
          metadata['user_email'] = seller.email
          metadata['user_id'] = seller.id.to_s
          click.update_column(:metadata, metadata)
          associated_count += 1
        end
        Rails.logger.info "Associated #{email_clicks.count} guest click events with seller #{seller.id} using email match" if defined?(Rails.logger)
      end
    end
    
    Rails.logger.info "Total guest clicks associated with seller #{seller.id}: #{associated_count}" if defined?(Rails.logger) && associated_count > 0
    
    associated_count
  rescue => e
    Rails.logger.error "Failed to associate guest clicks with seller #{seller.id}: #{e.message}" if defined?(Rails.logger)
    Rails.logger.error e.backtrace.first(10).join("\n") if defined?(Rails.logger)
    0
  end
end

