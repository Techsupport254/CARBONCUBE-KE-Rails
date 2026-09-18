# frozen_string_literal: true

class CreatePartnerActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :partner_activities, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :partner, type: :uuid, null: false, foreign_key: true
      t.references :sales_user, type: :uuid, foreign_key: true
      t.integer :activity_type, null: false, default: 5
      t.datetime :occurred_at, null: false
      t.text :notes
      t.string :outcome
      t.date :follow_up_date
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7

      t.timestamps
    end

    add_index :partner_activities, :activity_type
    add_index :partner_activities, :occurred_at
    add_index :partner_activities, :follow_up_date
  end
end
