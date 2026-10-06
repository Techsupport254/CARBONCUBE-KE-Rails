class AddPhotoUrlToSellerVerifications < ActiveRecord::Migration[7.1]
  def change
    add_column :seller_verifications, :photo_url, :string
  end
end
