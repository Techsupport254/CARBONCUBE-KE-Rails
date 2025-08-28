class CreateClickEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :click_events do |t|
      t.references :buyer, foreign_key: true, null: true # Nullable for guests
      t.references :ad, foreign_key: true, null: true # Nullable for clicks not tied to a ad
      t.string :event_type, null: false
      t.jsonb :metadata, default: {} # Additional info (e.g., seller ID)

      t.timestamps
    end
  end
end
