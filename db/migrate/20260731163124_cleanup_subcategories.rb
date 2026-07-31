class CleanupSubcategories < ActiveRecord::Migration[7.1]
  def up
    # 1. Delete dangling subcategories that point to a missing category and have no ads
    dangling_ids = Subcategory.where.not(category_id: Category.select(:id))
                              .left_outer_joins(:ads)
                              .where(ads: { id: nil })
                              .distinct
                              .pluck(:id)

    Subcategory.where(id: dangling_ids).delete_all if dangling_ids.any?

    # 2. Trim leading/trailing whitespace from subcategory names
    Subcategory.find_each do |subcategory|
      cleaned = subcategory.name.to_s.strip
      subcategory.update!(name: cleaned) if cleaned != subcategory.name
    end

    # 3. Rename generic subcategory names to be scoped by parent category
    category_short_names = {
      "Automotive Parts & Accessories" => "Automotive",
      "Computers, Phones and Accessories" => "Computer",
      "Agriculture" => "Agriculture",
      "Filtration" => "Filtration",
      "Hardware" => "Hardware",
      "Services" => "Services",
      "TVs & Home Entertainment" => "TV",
      "Electronics and Accessories" => "Electronics"
    }

    Subcategory.includes(:category).find_each do |subcategory|
      next unless subcategory.category

      short = category_short_names[subcategory.category.name]
      next unless short

      new_name = case subcategory.name
                 when "Accessories"
                   "#{short} Accessories"
                 when "Spare Parts"
                   "#{short} Spare Parts"
                 when "Others"
                   "Other #{short}"
                 else
                   nil
                 end

      next unless new_name

      # Skip if the target name already exists in the same category
      existing = Subcategory.where(category_id: subcategory.category_id, name: new_name).where.not(id: subcategory.id).first
      if existing
        # If a correctly-named record already exists, move its ads to that record
        # and delete this duplicate. Since both are in the same category, the
        # ads only need their subcategory_id updated.
        Ad.where(subcategory_id: subcategory.id).update_all(subcategory_id: existing.id) if Ad.exists?(subcategory_id: subcategory.id)
        subcategory.delete
      else
        subcategory.update!(name: new_name)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
