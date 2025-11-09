class CreateReviewRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :review_requests do |t|
      t.references :seller, null: false, foreign_key: true, type: :uuid
      t.text :reason
      t.string :status, default: 'pending'
      t.datetime :requested_at
      t.datetime :reviewed_at
      t.references :reviewed_by, polymorphic: true, type: :uuid
      t.text :review_notes

      t.timestamps
    end
    
    add_index :review_requests, :status
    add_index :review_requests, :requested_at
  end
end
