class AddOauthColumnsToAdmins < ActiveRecord::Migration[7.1]
  def change
    add_column :admins, :provider, :string
    add_column :admins, :uid, :string
    add_column :admins, :oauth_token, :string
    add_column :admins, :oauth_refresh_token, :string
    add_column :admins, :oauth_expires_at, :string
  end
end
