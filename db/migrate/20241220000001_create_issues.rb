class CreateIssues < ActiveRecord::Migration[7.0]
  def change
    create_table :issues do |t|
      t.string :title, null: false, limit: 200
      t.text :description, null: false, limit: 2000
      t.string :reporter_name, null: false, limit: 100
      t.string :reporter_email, null: false
      t.integer :status, default: 0, null: false # pending
      t.integer :priority, default: 1, null: false # medium
      t.integer :category, default: 0, null: false # bug
      t.boolean :public_visible, default: true
      t.references :assigned_to, null: true, foreign_key: { to_table: :admins }
      t.timestamp :resolved_at
      t.text :resolution_notes
      
      t.timestamps
    end
    
    add_index :issues, :status
    add_index :issues, :priority
    add_index :issues, :category
    add_index :issues, :public_visible
    # add_index :issues, :assigned_to_id  # Already created by references
    add_index :issues, :reporter_email
    add_index :issues, :created_at
    add_index :issues, [:status, :priority]
    add_index :issues, [:category, :status]
  end
end
