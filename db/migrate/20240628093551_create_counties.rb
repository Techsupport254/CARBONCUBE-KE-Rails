class CreateCounties < ActiveRecord::Migration[7.1]
  def change
    create_table :counties do |t|
      t.string :name, null: false
      t.string :capital, null: false
      t.integer :county_code, null: false

      t.timestamps
    end

    # Add unique indexes
    add_index :counties, :name, unique: true
    add_index :counties, :county_code, unique: true
  end
end
