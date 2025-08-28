class CreateAgeGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :age_groups do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :age_groups, :name, unique: true
  end
end
