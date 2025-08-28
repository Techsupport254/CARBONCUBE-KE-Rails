class CreateEducations < ActiveRecord::Migration[7.1]
  def change
    create_table :educations do |t|
      t.string :level, null: false
      t.timestamps
    end

    add_index :educations, :level, unique: true
  end
end
