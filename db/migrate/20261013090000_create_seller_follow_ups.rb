class CreateSellerFollowUps < ActiveRecord::Migration[7.1]
  # Follow-ups/issues logged against a shop during or after a field
  # verification. Hung on the seller (follow-ups outlive a single visit) with
  # an optional link back to the verification visit that raised them.
  # Mirrors the sales_brand_activities shape — type enum, occurred_at, notes,
  # follow_up_date — plus an open/resolved status so reported issues can be
  # tracked to closure.
  def change
    create_table :seller_follow_ups, id: :uuid do |t|
      t.references :seller, null: false, foreign_key: true, type: :uuid
      t.references :seller_verification, foreign_key: true, type: :uuid
      t.references :sales_user, foreign_key: true, type: :uuid
      t.string :actor_name
      t.integer :follow_up_type, null: false, default: 0
      t.text :notes
      t.string :status, null: false, default: 'open'
      t.date :follow_up_date
      t.datetime :occurred_at, null: false
      t.datetime :resolved_at
      t.timestamps

      t.index [:seller_id, :status]
      t.index :follow_up_date
      t.index :occurred_at
      t.index :status
    end
  end
end
