class DeleteDeletedSellersWithCascade < ActiveRecord::Migration[7.1]
  def up
    # Count deleted sellers and buyers
    deleted_sellers_count = execute("SELECT COUNT(*) as count FROM sellers WHERE deleted = true").first['count'].to_i
    deleted_buyers_count = execute("SELECT COUNT(*) as count FROM buyers WHERE deleted = true").first['count'].to_i
    
    if deleted_sellers_count == 0 && deleted_buyers_count == 0
      puts "No deleted sellers or buyers found. Nothing to delete."
      return
    end
    
    puts "Found #{deleted_sellers_count} deleted seller(s) and #{deleted_buyers_count} deleted buyer(s) to delete..."
    
    # Manually delete records from tables without cascade foreign keys
    # or polymorphic associations that don't have FK constraints
    
    # 1. Delete from categories_sellers join table (no FK constraint)
    puts "Deleting from categories_sellers..."
    deleted_categories_sellers = execute(
      "DELETE FROM categories_sellers WHERE seller_id IN (SELECT id FROM sellers WHERE deleted = true)"
    ).cmd_tuples
    puts "  Deleted #{deleted_categories_sellers} category associations"
    
    # 2. Delete review_requests (has FK but no cascade)
    puts "Deleting review_requests..."
    deleted_review_requests = execute(
      "DELETE FROM review_requests WHERE seller_id IN (SELECT id FROM sellers WHERE deleted = true)"
    ).cmd_tuples
    puts "  Deleted #{deleted_review_requests} review requests"
    
    # 3. Delete password_otps (polymorphic association, no FK constraint)
    puts "Deleting password_otps..."
    deleted_password_otps = execute(
      "DELETE FROM password_otps WHERE otpable_type = 'Seller' AND otpable_id IN (SELECT id FROM sellers WHERE deleted = true)"
    ).cmd_tuples
    puts "  Deleted #{deleted_password_otps} password OTPs"
    
    # 4. Delete sent_messages (polymorphic association, as: :sender)
    puts "Deleting sent_messages..."
    deleted_messages = execute(
      "DELETE FROM messages WHERE sender_type = 'Seller' AND sender_id IN (SELECT id FROM sellers WHERE deleted = true)"
    ).cmd_tuples
    puts "  Deleted #{deleted_messages} messages"
    
    # 5. Delete records from tables that reference ads but don't have cascade delete
    # These need to be deleted before ads are cascade deleted
    puts "Deleting ad-related records..."
    
    # Delete click_events for ads belonging to deleted sellers
    deleted_click_events = execute(
      "DELETE FROM click_events WHERE ad_id IN (SELECT id FROM ads WHERE seller_id IN (SELECT id FROM sellers WHERE deleted = true))"
    ).cmd_tuples
    puts "  Deleted #{deleted_click_events} click events"
    
    # Delete cart_items for ads belonging to deleted sellers
    deleted_cart_items = execute(
      "DELETE FROM cart_items WHERE ad_id IN (SELECT id FROM ads WHERE seller_id IN (SELECT id FROM sellers WHERE deleted = true))"
    ).cmd_tuples
    puts "  Deleted #{deleted_cart_items} cart items"
    
    # Delete reviews for ads belonging to deleted sellers
    deleted_reviews = execute(
      "DELETE FROM reviews WHERE ad_id IN (SELECT id FROM ads WHERE seller_id IN (SELECT id FROM sellers WHERE deleted = true))"
    ).cmd_tuples
    puts "  Deleted #{deleted_reviews} reviews"
    
    # Delete wish_lists for ads belonging to deleted sellers
    deleted_wish_lists = execute(
      "DELETE FROM wish_lists WHERE ad_id IN (SELECT id FROM ads WHERE seller_id IN (SELECT id FROM sellers WHERE deleted = true))"
    ).cmd_tuples
    puts "  Deleted #{deleted_wish_lists} wish list items"
    
    # Delete offer_ads for ads belonging to deleted sellers
    deleted_offer_ads = execute(
      "DELETE FROM offer_ads WHERE ad_id IN (SELECT id FROM ads WHERE seller_id IN (SELECT id FROM sellers WHERE deleted = true))"
    ).cmd_tuples
    puts "  Deleted #{deleted_offer_ads} offer ads"
    
    # Delete conversations for ads belonging to deleted sellers
    deleted_conversations = execute(
      "DELETE FROM conversations WHERE ad_id IN (SELECT id FROM ads WHERE seller_id IN (SELECT id FROM sellers WHERE deleted = true))"
    ).cmd_tuples
    puts "  Deleted #{deleted_conversations} conversations"
    
    # 6. Delete buyer-related records
    if deleted_buyers_count > 0
      puts "Deleting buyer-related records..."
      
      # Delete cart_items for deleted buyers
      deleted_buyer_cart_items = execute(
        "DELETE FROM cart_items WHERE buyer_id IN (SELECT id FROM buyers WHERE deleted = true)"
      ).cmd_tuples
      puts "  Deleted #{deleted_buyer_cart_items} cart items"
      
      # Delete wish_lists for deleted buyers
      deleted_buyer_wish_lists = execute(
        "DELETE FROM wish_lists WHERE buyer_id IN (SELECT id FROM buyers WHERE deleted = true)"
      ).cmd_tuples
      puts "  Deleted #{deleted_buyer_wish_lists} wish list items"
      
      # Delete conversations for deleted buyers
      deleted_buyer_conversations = execute(
        "DELETE FROM conversations WHERE buyer_id IN (SELECT id FROM buyers WHERE deleted = true)"
      ).cmd_tuples
      puts "  Deleted #{deleted_buyer_conversations} conversations"
      
      # Delete click_events for deleted buyers
      deleted_buyer_click_events = execute(
        "DELETE FROM click_events WHERE buyer_id IN (SELECT id FROM buyers WHERE deleted = true)"
      ).cmd_tuples
      puts "  Deleted #{deleted_buyer_click_events} click events"
      
      # Delete ad_searches for deleted buyers
      deleted_ad_searches = execute(
        "DELETE FROM ad_searches WHERE buyer_id IN (SELECT id FROM buyers WHERE deleted = true)"
      ).cmd_tuples
      puts "  Deleted #{deleted_ad_searches} ad searches"
      
      # Delete password_otps for deleted buyers (polymorphic)
      deleted_buyer_password_otps = execute(
        "DELETE FROM password_otps WHERE otpable_type = 'Buyer' AND otpable_id IN (SELECT id FROM buyers WHERE deleted = true)"
      ).cmd_tuples
      puts "  Deleted #{deleted_buyer_password_otps} password OTPs"
      
      # Delete sent_messages for deleted buyers (polymorphic)
      deleted_buyer_messages = execute(
        "DELETE FROM messages WHERE sender_type = 'Buyer' AND sender_id IN (SELECT id FROM buyers WHERE deleted = true)"
      ).cmd_tuples
      puts "  Deleted #{deleted_buyer_messages} messages"
      
      # Delete reviews written by deleted buyers
      deleted_buyer_reviews = execute(
        "DELETE FROM reviews WHERE buyer_id IN (SELECT id FROM buyers WHERE deleted = true)"
      ).cmd_tuples
      puts "  Deleted #{deleted_buyer_reviews} reviews"
    end
    
    # 7. Now delete the sellers themselves
    # The following tables will be automatically cascade deleted due to FK constraints:
    # - ads (on_delete: :cascade) - but we manually deleted dependent records above
    # - offers (on_delete: :cascade)
    # - payment_transactions (on_delete: :cascade)
    # - seller_documents (on_delete: :cascade)
    # - seller_tiers (on_delete: :cascade)
    # Note: wish_lists with seller_id will cascade, but we already deleted ad-related ones above
    if deleted_sellers_count > 0
      puts "Deleting sellers (cascade will handle dependent records)..."
      execute("DELETE FROM sellers WHERE deleted = true")
    end
    
    # 8. Delete the buyers themselves
    # The following tables will be automatically cascade deleted due to FK constraints:
    # - conversations (on_delete: :cascade) - but we manually deleted above
    # - wish_lists (on_delete: :cascade) - but we manually deleted above
    if deleted_buyers_count > 0
      puts "Deleting buyers (cascade will handle dependent records)..."
      execute("DELETE FROM buyers WHERE deleted = true")
    end
    
    puts "Successfully deleted #{deleted_sellers_count} seller(s) and #{deleted_buyers_count} buyer(s) and all associated records."
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot reverse deletion of sellers and buyers"
  end
end
