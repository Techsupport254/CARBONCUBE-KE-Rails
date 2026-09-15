# frozen_string_literal: true

class CreateSalesBrands < ActiveRecord::Migration[7.1]
  def change
    create_table :sales_brands, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :name, null: false
      t.integer :part, default: 1, null: false
      t.string :category
      t.string :subcategories, array: true, default: []
      t.text :scope
      t.string :location
      t.string :phone
      t.string :email
      t.string :website
      t.string :twitter

      # Outreach tracking
      t.integer :status, default: 0, null: false
      t.date :follow_up_date
      t.text :follow_up_note
      t.text :notes
      t.datetime :last_contacted_at
      t.references :sales_user, type: :uuid, foreign_key: true

      t.timestamps
    end

    add_index :sales_brands, :status
    add_index :sales_brands, :follow_up_date
    add_index :sales_brands, :category
  end
end
