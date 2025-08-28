class CreateAbouts < ActiveRecord::Migration[7.1]
  def change
    create_table :abouts do |t|
      t.text :description
      t.text :mission
      t.text :vision
      t.jsonb :values, default: []
      t.text :why_choose_us
      t.string :image_url

      t.timestamps
    end
  end
end
