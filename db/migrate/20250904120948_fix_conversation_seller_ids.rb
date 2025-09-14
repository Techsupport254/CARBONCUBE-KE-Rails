class FixConversationSellerIds < ActiveRecord::Migration[7.1]
  def up
    # Find conversations that have an ad_id but no seller_id or admin_id
    conversations_to_fix = Conversation.where('ad_id IS NOT NULL AND seller_id IS NULL AND admin_id IS NULL')
    
    puts "Found #{conversations_to_fix.count} conversations to fix"
    
    conversations_to_fix.each do |conversation|
      begin
        ad = Ad.find(conversation.ad_id)
        conversation.update!(seller_id: ad.seller_id)
        puts "Fixed conversation #{conversation.id}: set seller_id to #{ad.seller_id}"
      rescue => e
        puts "Error fixing conversation #{conversation.id}: #{e.message}"
      end
    end
  end

  def down
    # This migration is not reversible as we're fixing data integrity issues
    puts "This migration cannot be reversed as it fixes data integrity issues"
  end
end
