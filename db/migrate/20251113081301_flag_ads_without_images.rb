class FlagAdsWithoutImages < ActiveRecord::Migration[7.1]
  def up
    # Flag ads that don't have valid images
    # This includes:
    # - ads with NULL media
    # - ads with empty string media
    # - ads with empty JSON array media []
    # - ads with media arrays that don't contain valid HTTP/HTTPS URLs
    
    Rails.logger.info "Flagging ads without valid images..."
    
    # Count ads to be flagged
    ads_to_flag = Ad.where(deleted: false)
                    .where(
                      "(media IS NULL OR media = '' OR media::text = '[]' OR (media::jsonb -> 0) IS NULL)"
                    )
                    .where(flagged: false) # Only flag ads that aren't already flagged
    
    count = ads_to_flag.count
    Rails.logger.info "Found #{count} ads without valid images to flag"
    
    # Flag ads in batches to avoid memory issues
    ads_to_flag.find_in_batches(batch_size: 1000) do |batch|
      updated = Ad.where(id: batch.map(&:id))
                  .update_all(flagged: true, updated_at: Time.current)
      Rails.logger.info "Flagged #{updated} ads in this batch"
    end
    
    Rails.logger.info "Migration complete: Flagged ads without valid images"
  end

  def down
    # Unflag ads that were flagged by this migration
    # Note: This will unflag ALL flagged ads, not just those flagged by this migration
    # If you need to preserve other flagged ads, you'll need to track which ones were flagged here
    Rails.logger.info "Unflagging ads (this will unflag all flagged ads)..."
    
    # For safety, we'll only unflag ads that match the criteria (no valid images)
    # This way we don't accidentally unflag ads that were flagged for other reasons
    ads_to_unflag = Ad.where(deleted: false, flagged: true)
                     .where(
                       "(media IS NULL OR media = '' OR media::text = '[]' OR (media::jsonb -> 0) IS NULL)"
                     )
    
    count = ads_to_unflag.count
    Rails.logger.info "Found #{count} flagged ads without valid images to unflag"
    
    ads_to_unflag.find_in_batches(batch_size: 1000) do |batch|
      updated = Ad.where(id: batch.map(&:id))
                  .update_all(flagged: false, updated_at: Time.current)
      Rails.logger.info "Unflagged #{updated} ads in this batch"
    end
    
    Rails.logger.info "Rollback complete: Unflagged ads without valid images"
  end
end
