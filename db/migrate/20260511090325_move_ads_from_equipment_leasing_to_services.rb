class MoveAdsFromEquipmentLeasingToServices < ActiveRecord::Migration[7.1]
  def change
    # Find the old Equipment Leasing category
    old_equipment_leasing_category = Category.find_by(name: "Equipment Leasing")

    # Find the new Services category and Equipment Leasing subcategory
    services_category = Category.find_by(name: "Services")
    new_equipment_leasing_subcategory = services_category&.subcategories&.find_by(name: "Equipment Leasing")

    if old_equipment_leasing_category && new_equipment_leasing_subcategory
      # Move all ads from old category to new subcategory
      ads_count = old_equipment_leasing_category.ads.count

      # Update ads to point to the new category and subcategory
      old_equipment_leasing_category.ads.update_all(
        category_id: services_category.id,
        subcategory_id: new_equipment_leasing_subcategory.id
      )

      puts "Successfully moved #{ads_count} ads from 'Equipment Leasing' category to 'Services > Equipment Leasing' subcategory"
    else
      if !old_equipment_leasing_category
        puts "Warning: Old 'Equipment Leasing' category not found"
      end
      if !new_equipment_leasing_subcategory
        puts "Warning: New 'Equipment Leasing' subcategory under Services not found"
      end
    end
  end

  def down
    # Revert: Move ads back from Services > Equipment Leasing to old Equipment Leasing category
    old_equipment_leasing_category = Category.find_by(name: "Equipment Leasing")
    services_category = Category.find_by(name: "Services")
    new_equipment_leasing_subcategory = services_category&.subcategories&.find_by(name: "Equipment Leasing")

    if old_equipment_leasing_category && new_equipment_leasing_subcategory
      # Find the original subcategory IDs from the old category
      # We'll need to map ads back to their original subcategories or use a default
      # For simplicity, we'll use the first subcategory or "Others" if available
      default_subcategory = old_equipment_leasing_category.subcategories.first

      ads_count = new_equipment_leasing_subcategory.ads.count

      new_equipment_leasing_subcategory.ads.update_all(
        category_id: old_equipment_leasing_category.id,
        subcategory_id: default_subcategory&.id || old_equipment_leasing_category.subcategories.create!(name: "Others").id
      )

      puts "Successfully reverted #{ads_count} ads back to 'Equipment Leasing' category"
    end
  end
end
