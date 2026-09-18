# frozen_string_literal: true

class CreatePartnerInvites < ActiveRecord::Migration[7.1]
  def change
    create_table :partner_invites, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :invitee, type: :uuid, polymorphic: true, null: false
      t.references :seller, type: :uuid, foreign_key: { on_delete: :nullify }
      t.references :invited_by, type: :uuid, polymorphic: true

      t.string :email
      t.string :phone
      t.string :token, null: false

      t.integer :status, null: false, default: 0
      t.integer :invite_kind, null: false, default: 0

      t.integer :reminder_count, null: false, default: 0
      t.datetime :invite_sent_at
      t.datetime :last_reminded_at
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :partner_invites, :token, unique: true
    add_index :partner_invites, :status
    add_index :partner_invites, :expires_at
  end
end
