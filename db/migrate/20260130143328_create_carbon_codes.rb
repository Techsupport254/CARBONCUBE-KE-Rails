class CreateCarbonCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :carbon_codes do |t|
      t.string :code, null: false
      t.string :label
      t.datetime :expires_at
      t.integer :max_uses
      t.integer :times_used, default: 0, null: false
      t.string :associable_type, null: false
      t.uuid :associable_id, null: false

      t.timestamps
    end

    add_index :carbon_codes, :code, unique: true
    add_index :carbon_codes, [:associable_type, :associable_id]
  end
end
