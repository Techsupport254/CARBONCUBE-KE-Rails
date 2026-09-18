# frozen_string_literal: true

class CreatePartnerContacts < ActiveRecord::Migration[7.1]
  def change
    create_table :partner_contacts, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :partner, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :role_title
      t.string :email
      t.string :phone
      t.boolean :is_primary, null: false, default: false
      t.boolean :receives_updates, null: false, default: true
      t.text :notes

      t.timestamps
    end

    add_index :partner_contacts, :is_primary
  end
end
