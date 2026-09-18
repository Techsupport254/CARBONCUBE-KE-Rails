# frozen_string_literal: true

class CreatePartnerDistributors < ActiveRecord::Migration[7.1]
  def change
    create_table :partner_distributors, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :partner, type: :uuid, null: false, foreign_key: true
      t.references :seller, type: :uuid, foreign_key: { on_delete: :nullify },
                            index: { unique: true }
      t.references :sales_user, type: :uuid, foreign_key: true

      t.string :name, null: false
      t.string :contact_person
      t.string :phone
      t.string :email
      t.string :location

      t.integer :status, null: false, default: 0
      t.boolean :notify_pricing, null: false, default: true
      t.boolean :notify_updates, null: false, default: true
      t.text :notes

      t.timestamps
    end

    add_index :partner_distributors, :status
  end
end
