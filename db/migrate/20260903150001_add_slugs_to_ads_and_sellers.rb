class AddSlugsToAdsAndSellers < ActiveRecord::Migration[7.1]
  def up
    add_column :ads, :slug, :string unless column_exists?(:ads, :slug)
    add_column :sellers, :slug, :string unless column_exists?(:sellers, :slug)

    Ad.reset_column_information
    Seller.reset_column_information

    Ad.where(slug: [nil, ""]).find_each do |ad|
      base = ad.title.to_s.parameterize
      base = "ad" if base.blank?
      ad.update_column(:slug, "#{base}-#{ad.id}")
    end

    Seller.where(slug: [nil, ""]).find_each do |seller|
      base = (seller.enterprise_name || seller.fullname).to_s.parameterize
      base = "shop" if base.blank?
      seller.update_column(:slug, "#{base}-#{seller.id}")
    end

    add_index :ads, :slug, unique: true, if_not_exists: true
    add_index :sellers, :slug, unique: true, if_not_exists: true
  end

  def down
    remove_index :ads, :slug if index_exists?(:ads, :slug)
    remove_index :sellers, :slug if index_exists?(:sellers, :slug)
    remove_column :ads, :slug if column_exists?(:ads, :slug)
    remove_column :sellers, :slug if column_exists?(:sellers, :slug)
  end
end
