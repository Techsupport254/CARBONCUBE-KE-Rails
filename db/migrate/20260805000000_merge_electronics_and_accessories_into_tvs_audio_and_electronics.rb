class MergeElectronicsAndAccessoriesIntoTvsAudioAndElectronics < ActiveRecord::Migration[7.1]
  def up
    old_tv_name = "TVs & Home Entertainment"
    old_ea_name = "Electronics and Accessories"
    new_name = "TVs & Audio and Electronics"

    target_category = Category.find_by(name: old_tv_name)
    source_category = Category.find_by(name: old_ea_name)

    raise "Target category '#{old_tv_name}' not found" unless target_category
    raise "Source category '#{old_ea_name}' not found" unless source_category

    target_category.update!(
      name: new_name,
      description: "Televisions, home audio, office electronics, and electronic accessories including TVs, sound systems, projectors, printers, POS systems, and more."
    )

    target_category.subcategories.find_or_create_by!(name: "Electronics Accessories")
    target_category.subcategories.find_or_create_by!(name: "Audio Accessories")

    target_projectors = target_category.subcategories.find_by(name: "Projectors & Screens")
    source_projectors = source_category.subcategories.find_by(name: "Projectors")

    source_category.subcategories.where.not(name: "Projectors").find_each do |subcategory|
      subcategory.update!(category: target_category)
    end

    if source_projectors
      if target_projectors
        Ad.where(subcategory_id: source_projectors.id).update_all(subcategory_id: target_projectors.id)
        source_projectors.destroy!
      else
        source_projectors.update!(category: target_category)
      end
    end

    Ad.where(category_id: source_category.id).update_all(category_id: target_category.id)

    SellerPricingTemplate.where(category_id: source_category.id).update_all(category_id: target_category.id)
    if source_projectors && target_projectors
      SellerPricingTemplate.where(subcategory_id: source_projectors.id).update_all(subcategory_id: target_projectors.id)
    end

    sellers_to_associate = CategoriesSeller.where(category_id: source_category.id)
                                          .where.not(seller_id: CategoriesSeller.where(category_id: target_category.id).select(:seller_id))
                                          .distinct
                                          .pluck(:seller_id)

    sellers_to_associate.each do |seller_id|
      CategoriesSeller.create!(category_id: target_category.id, seller_id: seller_id)
    end

    CategoriesSeller.where(category_id: source_category.id).destroy_all

    source_category.destroy!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
