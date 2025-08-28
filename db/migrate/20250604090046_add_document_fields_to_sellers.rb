class AddDocumentFieldsToSellers < ActiveRecord::Migration[7.0]
  def change
    add_reference :sellers, :document_type, foreign_key: true
    add_column :sellers, :document_expiry_date, :date
    add_column :sellers, :document_verified, :boolean, default: false
    rename_column :sellers, :business_permit, :document_url
  end
end
