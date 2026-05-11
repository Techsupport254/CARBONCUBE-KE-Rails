class CreateServicesCategoryAndSubcategories < ActiveRecord::Migration[7.1]
  def change
    # Create Services category
    services_category = Category.find_or_create_by!(name: "Services") do |category|
      category.description = "Professional services including repairs, leasing, and mechanics"
    end

    # Create subcategories under Services
    subcategories = ["Computer Repairs", "Equipment Leasing", "Mechanics"]

    subcategories.each do |sub_name|
      services_category.subcategories.find_or_create_by!(name: sub_name)
    end

    puts "Successfully created Services category with subcategories: #{subcategories.join(', ')}"
  end

  def down
    # Revert: Delete the Services category and its subcategories
    services_category = Category.find_by(name: "Services")
    if services_category
      services_category.subcategories.destroy_all
      services_category.destroy
      puts "Successfully deleted Services category and its subcategories"
    end
  end
end
