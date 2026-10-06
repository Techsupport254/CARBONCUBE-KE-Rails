class AddBuildingAndRoomToSellers < ActiveRecord::Migration[7.1]
  def up
    change_table :sellers, bulk: true do |t|
      t.string :building
      t.string :room
    end

    # Backfill from each seller's latest successful field verification.
    execute <<~SQL.squish
      UPDATE sellers s
      SET building = v.building, room = v.room
      FROM (
        SELECT DISTINCT ON (seller_id) seller_id, building, room
        FROM seller_verifications
        WHERE outcome IN ('verified', 'corrected')
          AND (building IS NOT NULL OR room IS NOT NULL)
        ORDER BY seller_id, created_at DESC
      ) v
      WHERE v.seller_id = s.id
    SQL
  end

  def down
    remove_columns :sellers, :building, :room
  end
end
