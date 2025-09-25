class AddOauthFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :oauth_token, :string
    add_column :users, :oauth_refresh_token, :string
    add_column :users, :oauth_expires_at, :string
  end
end
