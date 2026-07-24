class AddRepairSubcategoriesToServices < ActiveRecord::Migration[7.1]
  def up
    services_category = Category.find_by(name: "Services")

    if services_category
      subcategories = [
        "Electrician",
        "Plumber",
        "Appliance Specialist",
        "Electronics Specialist",
        "Welder",
        "Mason",
        "Painter",
        "Carpenter",
        "Industrial Machinery Specialist",
        "Borehole Specialist",
        "Phone Repairs"
      ]

      subcategories.each do |sub_name|
        services_category.subcategories.find_or_create_by!(name: sub_name)
      end

      puts "Successfully added subcategories to Services: #{subcategories.join(', ')}"
    else
      puts "Warning: 'Services' category not found. Please create it first."
    end
  end

  def down
    services_category = Category.find_by(name: "Services")
    if services_category
      subcategories = [
        "Electrician",
        "Plumber",
        "Appliance Specialist",
        "Electronics Specialist",
        "Welder",
        "Mason",
        "Painter",
        "Carpenter",
        "Industrial Machinery Specialist",
        "Borehole Specialist",
        "Phone Repairs"
      ]

      services_category.subcategories.where(name: subcategories).destroy_all
      puts "Removed repair subcategories from Services"
    else
      puts "Warning: 'Services' category not found"
    end
  end
end
