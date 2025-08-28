class CreateTierFeatures < ActiveRecord::Migration[7.1]
  def change
    create_table :tier_features do |t|
      t.references :tier, null: false, foreign_key: true
      t.string :feature_name, null: false
      t.timestamps
    end
  end
end
