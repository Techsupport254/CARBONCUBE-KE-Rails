class CreateSellerDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :seller_documents do |t|
      t.references :seller, null: false, foreign_key: true
      t.references :document_type, null: false, foreign_key: true
      t.string :document_url
      t.date :document_expiry_date
      t.boolean :document_verified, default: false

      t.timestamps
    end

    add_index :seller_documents, [:seller_id, :document_type_id], unique: true
  end
end
