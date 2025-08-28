class CreateEmployments < ActiveRecord::Migration[7.1]
  def change
    create_table :employments do |t|
      t.string :status, null: false
      t.timestamps
    end

    add_index :employments, :status, unique: true
  end
end
