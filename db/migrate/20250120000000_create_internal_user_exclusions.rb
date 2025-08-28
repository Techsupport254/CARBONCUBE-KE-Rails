class CreateInternalUserExclusions < ActiveRecord::Migration[8.0]
  def change
    create_table :internal_user_exclusions do |t|
      t.string :identifier_type, null: false
      t.text :identifier_value, null: false
      t.text :reason, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    
    add_index :internal_user_exclusions, :identifier_type
    add_index :internal_user_exclusions, :active
    add_index :internal_user_exclusions, [:identifier_type, :identifier_value], unique: true, name: 'index_internal_user_exclusions_on_type_and_value'
  end
end
