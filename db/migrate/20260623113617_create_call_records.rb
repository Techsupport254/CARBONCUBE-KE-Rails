class CreateCallRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :call_records, id: :uuid do |t|
      t.references :customer, polymorphic: true, type: :uuid, null: true
      t.references :sales_user, type: :uuid, null: true, foreign_key: true
      t.integer :status
      t.integer :call_type
      t.integer :duration_seconds
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :csat_score

      t.timestamps
    end
  end
end
