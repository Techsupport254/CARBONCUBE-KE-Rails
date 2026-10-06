class AddPerformanceIndexesToSellerVerifications < ActiveRecord::Migration[7.1]
  def change
    # Scoped listing: WHERE sales_user_id IN (...) ORDER BY created_at DESC
    add_index :seller_verifications, [:sales_user_id, :created_at]
    # Per-seller verification history
    add_index :seller_verifications, [:seller_id, :created_at]
    # Stats group-by + suspicious-verdict filtering
    add_index :seller_verifications, :gps_verdict
    # Verified/unverified seller filtering
    add_index :sellers, :field_verified_at
  end
end
