class AddBannerUrlToSellers < ActiveRecord::Migration[7.1]
  def up
    add_column :sellers, :banner_url, :string

    # Backfill: the shop-front photo captured during the latest successful
    # field verification becomes the shop's public banner.
    execute <<~SQL.squish
      UPDATE sellers s
      SET banner_url = v.photo_url
      FROM (
        SELECT DISTINCT ON (seller_id) seller_id, photo_url
        FROM seller_verifications
        WHERE outcome IN ('verified', 'corrected') AND photo_url IS NOT NULL
        ORDER BY seller_id, created_at DESC
      ) v
      WHERE v.seller_id = s.id
    SQL
  end

  def down
    remove_column :sellers, :banner_url
  end
end
