class AddOauthColumnsToSalesUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_users, :provider, :string
    add_column :sales_users, :uid, :string
    add_column :sales_users, :oauth_token, :string
    add_column :sales_users, :oauth_refresh_token, :string
    add_column :sales_users, :oauth_expires_at, :string
  end
end
