class CreateMarketingUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :marketing_users, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :fullname
      t.string :email
      t.string :password_digest
      t.string :provider
      t.string :uid
      t.string :oauth_token
      t.string :oauth_refresh_token
      t.string :oauth_expires_at

      t.timestamps
    end
    
    add_index :marketing_users, :id, unique: true, name: "index_marketing_users_on_uuid"
  end
end
