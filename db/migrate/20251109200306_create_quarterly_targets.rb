class CreateQuarterlyTargets < ActiveRecord::Migration[7.1]
  def change
    create_table :quarterly_targets, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :metric_type, null: false # e.g., "total_sellers", "total_buyers"
      t.integer :year, null: false
      t.integer :quarter, null: false # 1, 2, 3, or 4
      t.integer :target_value, null: false
      t.string :status, default: "pending", null: false # pending, approved, rejected
      t.uuid :created_by_id, null: false # SalesUser who created the target
      t.uuid :approved_by_id # Admin who approved/rejected
      t.datetime :approved_at
      t.text :notes

      t.timestamps
    end

    # Add indexes for efficient queries
    add_index :quarterly_targets, [:metric_type, :year, :quarter], unique: true, name: "index_quarterly_targets_on_metric_year_quarter"
    add_index :quarterly_targets, :status
    add_index :quarterly_targets, :created_by_id
    add_index :quarterly_targets, :approved_by_id
    add_index :quarterly_targets, [:year, :quarter]

    # Add foreign key constraints (optional, but good for data integrity)
    # Note: We can't add foreign keys to sales_users and admins if they're in different schemas
    # but we'll add them if they're in the same schema
  end
end
