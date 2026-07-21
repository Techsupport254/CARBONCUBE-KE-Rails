class AddSocialMediaToSellers < ActiveRecord::Migration[7.1]
  def change
    add_column :sellers, :facebook_url, :string
    add_column :sellers, :instagram_url, :string
    add_column :sellers, :whatsapp_url, :string
    add_column :sellers, :tiktok_url, :string
    add_column :sellers, :twitter_url, :string
    add_column :sellers, :linkedin_url, :string
  end
end
