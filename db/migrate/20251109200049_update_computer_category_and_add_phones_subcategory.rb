class UpdateComputerCategoryAndAddPhonesSubcategory < ActiveRecord::Migration[7.1]
  def up
    # Find the Computer, Parts & Accessories category
    computer_category = Category.find_by(name: "Computer, Parts & Accessories")
    
    if computer_category
      # Update the category name
      computer_category.update(name: "Computer, Phones and Accessories")
      
      # Check if Phones subcategory already exists
      phones_subcategory = computer_category.subcategories.find_by(name: "Phones")
      
      # Create Phones subcategory if it doesn't exist
      unless phones_subcategory
        computer_category.subcategories.create!(name: "Phones")
      end
    else
      # If category doesn't exist with exact name, try to find similar
      computer_category = Category.where("name ILIKE ?", "%computer%").first
      
      if computer_category
        computer_category.update(name: "Computer, Phones and Accessories")
        
        phones_subcategory = computer_category.subcategories.find_by(name: "Phones")
        unless phones_subcategory
          computer_category.subcategories.create!(name: "Phones")
        end
      else
        puts "Warning: Computer category not found. Please create it manually."
      end
    end
  end

  def down
    # Find the Computer, Phones and Accessories category
    computer_category = Category.find_by(name: "Computer, Phones and Accessories")
    
    if computer_category
      # Revert the category name
      computer_category.update(name: "Computer, Parts & Accessories")
      
      # Remove Phones subcategory
      phones_subcategory = computer_category.subcategories.find_by(name: "Phones")
      phones_subcategory&.destroy
    end
  end
end

