class CreateElectronicsAndAccessoriesCategory < ActiveRecord::Migration[7.1]
  def up
    category = Category.find_or_create_by!(name: "Electronics and Accessories") do |cat|
      cat.description = "Office and consumer electronics including printers, copiers, scanners, POS systems, shredders, and projectors"
    end

    subcategories = [
      "Printers",
      "Copiers",
      "Scanners",
      "POS Systems",
      "Shredders",
      "Projectors",
      "Others"
    ]

    subcategories.each do |sub_name|
      category.subcategories.find_or_create_by!(name: sub_name)
    end

    puts "Successfully created 'Electronics and Accessories' category with subcategories: #{subcategories.join(', ')}"
  end

  def down
    category = Category.find_by(name: "Electronics and Accessories")
    if category
      category.subcategories.destroy_all
      category.destroy
      puts "Successfully deleted 'Electronics and Accessories' category and its subcategories"
    else
      puts "Warning: 'Electronics and Accessories' category not found"
    end
  end
end
