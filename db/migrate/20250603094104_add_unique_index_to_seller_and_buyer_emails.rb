class AddUniqueIndexToSellerAndBuyerEmails < ActiveRecord::Migration[7.1]
  def change
    remove_index :sellers, :email if index_exists?(:sellers, :email)
    remove_index :buyers, :email if index_exists?(:buyers, :email)

    add_index :sellers, 'LOWER(email)', unique: true, name: 'index_sellers_on_lower_email'
    add_index :buyers, 'LOWER(email)', unique: true, name: 'index_buyers_on_lower_email'
  end
end
