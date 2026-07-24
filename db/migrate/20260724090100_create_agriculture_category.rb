class CreateAgricultureCategory < ActiveRecord::Migration[7.1]
  def up
    category = Category.find_or_create_by!(name: "Agriculture") do |cat|
      cat.description = "Farm tools, irrigation, farm machinery, spare parts, and accessories"
    end

    subcategories = [
      "Farm Tools",
      "Irrigation",
      "Farm Machinery",
      "Spare Parts",
      "Accessories",
      "Others"
    ]

    subcategories.each do |sub_name|
      category.subcategories.find_or_create_by!(name: sub_name)
    end

    puts "Successfully created 'Agriculture' category with subcategories: #{subcategories.join(', ')}"
  end

  def down
    category = Category.find_by(name: "Agriculture")
    if category
      category.subcategories.destroy_all
      category.destroy
      puts "Successfully deleted 'Agriculture' category and its subcategories"
    else
      puts "Warning: 'Agriculture' category not found"
    end
  end
end
