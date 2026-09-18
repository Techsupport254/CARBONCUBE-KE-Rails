# frozen_string_literal: true

class CreatePartnerUpdates < ActiveRecord::Migration[7.1]
  def change
    create_table :partner_updates, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :partner, type: :uuid, null: false, foreign_key: true
      t.references :sales_user, type: :uuid, foreign_key: true
      t.references :ad, foreign_key: true

      t.integer :kind, null: false, default: 1
      t.string :title, null: false
      t.text :body
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :partner_updates, :kind
    add_index :partner_updates, :created_at
  end
end
