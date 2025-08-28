class CreateSectors < ActiveRecord::Migration[7.1]
  def change
    create_table :sectors do |t|
      t.string :name, null: false
      t.timestamps
    end

    add_index :sectors, :name, unique: true
  end
end
