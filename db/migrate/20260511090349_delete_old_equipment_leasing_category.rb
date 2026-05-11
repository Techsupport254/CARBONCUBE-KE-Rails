class DeleteOldEquipmentLeasingCategory < ActiveRecord::Migration[7.1]
  def change
    # Find the old Equipment Leasing category
    old_equipment_leasing_category = Category.find_by(name: "Equipment Leasing")

    if old_equipment_leasing_category
      # Check if there are any remaining ads in this category
      ads_count = old_equipment_leasing_category.ads.count

      if ads_count > 0
        puts "Warning: Equipment Leasing category still has #{ads_count} ads. Please run the previous migration to move them first."
        raise ActiveRecord::Rollback, "Cannot delete category with existing ads"
      else
        # Delete all subcategories of the old Equipment Leasing category
        old_equipment_leasing_category.subcategories.destroy_all

        # Delete the old category
        old_equipment_leasing_category.destroy
        puts "Successfully deleted old 'Equipment Leasing' category and its subcategories"
      end
    else
      puts "Warning: Old 'Equipment Leasing' category not found - may have already been deleted"
    end
  end

  def down
    # Revert: This migration cannot be easily reversed since we deleted the category
    # The category would need to be recreated with its original subcategories
    puts "Warning: This migration cannot be automatically reversed. The Equipment Leasing category was deleted."
    puts "To restore, you would need to manually recreate the category and its subcategories."
  end
end
