# frozen_string_literal: true

class CreatePartners < ActiveRecord::Migration[7.1]
  def change
    create_table :partners, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :name, null: false
      t.integer :partner_type, null: false, default: 0
      t.integer :status, null: false, default: 0

      # Contact details
      t.string :contact_person
      t.string :phone
      t.string :email
      t.string :website
      t.string :location
      t.string :logo_url
      t.text :description

      # Agreement
      t.date :signed_on
      t.text :agreement_notes
      t.decimal :commission_rate, precision: 5, scale: 2

      # Outreach / relationship tracking
      t.date :follow_up_date
      t.text :follow_up_note
      t.datetime :last_contacted_at
      t.text :notes

      t.references :seller, type: :uuid, foreign_key: { on_delete: :nullify },
                            index: { unique: true }
      t.references :sales_brand, type: :uuid, foreign_key: { on_delete: :nullify },
                                 index: { unique: true }
      t.references :sales_user, type: :uuid, foreign_key: true

      t.timestamps
    end

    add_index :partners, :partner_type
    add_index :partners, :status
    add_index :partners, :follow_up_date
  end
end
