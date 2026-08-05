class AddComputerSparePartsSubcategory < ActiveRecord::Migration[7.1]
  def up
    category = Category.find_by!(name: "Computers, Phones and Accessories")
    category.subcategories.find_or_create_by!(name: "Computer Spare Parts")
  end

  def down
    category = Category.find_by(name: "Computers, Phones and Accessories")
    subcategory = category&.subcategories&.find_by(name: "Computer Spare Parts")
    subcategory&.destroy!
  end
end
