class UpdateComputerToComputersInCategoryName < ActiveRecord::Migration[7.1]
  def up
    # Find the Computer, Phones and Accessories category
    computer_category = Category.find_by(name: "Computer, Phones and Accessories")
    
    if computer_category
      # Update the category name to plural
      computer_category.update(name: "Computers, Phones and Accessories")
    else
      # If category doesn't exist with exact name, try to find similar
      computer_category = Category.where("name ILIKE ?", "%computer%phones%").first
      
      if computer_category
        computer_category.update(name: "Computers, Phones and Accessories")
      else
        puts "Warning: Computer category not found. Please update it manually."
      end
    end
  end

  def down
    # Revert the category name back to singular
    computer_category = Category.find_by(name: "Computers, Phones and Accessories")
    
    if computer_category
      computer_category.update(name: "Computer, Phones and Accessories")
    end
  end
end

