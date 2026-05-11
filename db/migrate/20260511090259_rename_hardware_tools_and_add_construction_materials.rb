class RenameHardwareToolsAndAddConstructionMaterials < ActiveRecord::Migration[7.1]
  def change
    # Rename Hardware Tools to Hardware
    hardware_category = Category.find_by(name: "Hardware Tools")
    if hardware_category
      hardware_category.update(name: "Hardware")
      puts "Successfully renamed 'Hardware Tools' to 'Hardware'"
    else
      puts "Warning: 'Hardware Tools' category not found"
    end

    # Add Construction Materials subcategory under Hardware
    if hardware_category
      hardware_category.subcategories.find_or_create_by!(name: "Construction Materials")
      puts "Successfully added 'Construction Materials' subcategory under Hardware"
    end
  end

  def down
    # Revert: Rename Hardware back to Hardware Tools and remove Construction Materials
    hardware_category = Category.find_by(name: "Hardware")
    if hardware_category
      hardware_category.update(name: "Hardware Tools")
      puts "Successfully reverted 'Hardware' to 'Hardware Tools'"

      # Remove Construction Materials subcategory
      construction_materials = hardware_category.subcategories.find_by(name: "Construction Materials")
      if construction_materials
        construction_materials.destroy
        puts "Successfully removed 'Construction Materials' subcategory"
      end
    end
  end
end
