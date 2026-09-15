# frozen_string_literal: true

class CreateSalesBrandActivitiesAndBrandRegistration < ActiveRecord::Migration[7.1]
  def change
    create_table :sales_brand_activities, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :sales_brand, type: :uuid, null: false, foreign_key: true
      t.references :sales_user, type: :uuid, foreign_key: true
      t.integer :activity_type, null: false, default: 5
      t.datetime :occurred_at, null: false
      t.text :notes
      t.string :outcome
      t.date :follow_up_date

      t.timestamps
    end

    add_index :sales_brand_activities, :activity_type
    add_index :sales_brand_activities, :occurred_at
    add_index :sales_brand_activities, :follow_up_date

    change_table :sales_brands, bulk: true do |t|
      t.references :seller, type: :uuid, foreign_key: true
      t.datetime :registered_at
    end
  end
end
