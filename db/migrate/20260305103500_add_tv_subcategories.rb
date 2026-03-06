class AddTvSubcategories < ActiveRecord::Migration[7.1]
  def up
    category_name = "TVs & Home Entertainment"
    category = Category.find_or_create_by!(name: category_name)

    subcategories = [
      "Smart TVs",
      "LED & LCD TVs",
      "OLED & QLED TVs",
      "Home Theater Systems",
      "Soundbars & Speakers",
      "Streaming Devices",
      "Decoders & Receivers",
      "Projectors & Screens",
      "TV Accessories"
    ]

    subcategories.each do |sub_name|
      category.subcategories.find_or_create_by!(name: sub_name)
    end

    puts "Successfully added #{subcategories.length} subcategories to '#{category_name}'"
  end

  def down
    category = Category.find_by(name: "TVs & Home Entertainment")
    if category
      subcategories = [
        "Smart TVs",
        "LED & LCD TVs",
        "OLED & QLED TVs",
        "Home Theater Systems",
        "Soundbars & Speakers",
        "Streaming Devices",
        "Decoders & Receivers",
        "Projectors & Screens",
        "TV Accessories"
      ]
      category.subcategories.where(name: subcategories).destroy_all
      puts "Removed TV subcategories"
    end
  end
end
