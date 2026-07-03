class CreateBranches < ActiveRecord::Migration[7.1]
  def change
    create_table :branches, id: :uuid do |t|
      t.uuid :seller_id, null: false
      t.string :name
      t.text :description
      t.string :location
      t.float :latitude
      t.float :longitude
      t.string :phone
      t.string :email
      t.boolean :is_main_branch, default: false

      t.timestamps
    end

    add_foreign_key :branches, :sellers, column: :seller_id
    add_index :branches, :seller_id
  end
end
