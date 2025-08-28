class CreateAdSearches < ActiveRecord::Migration[7.1]
  def change
    create_table :ad_searches do |t|
      t.string :search_term, null: false
      t.references :buyer, foreign_key: true, null: true # Nullable for guests

      t.timestamps
    end
  end
end
