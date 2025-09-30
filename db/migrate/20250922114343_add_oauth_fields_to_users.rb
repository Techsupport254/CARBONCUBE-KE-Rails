class AddOauthFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :buyers, :provider, :string
    add_column :buyers, :uid, :string
    add_column :buyers, :oauth_token, :string
    add_column :buyers, :oauth_refresh_token, :string
    add_column :buyers, :oauth_expires_at, :string
  end
end
