# frozen_string_literal: true

class CreateRestoreCredentials < ActiveRecord::Migration[7.1]
  def change
    create_table :restore_credentials do |t|
      t.references :user, polymorphic: true, null: false, index: { unique: true }
      t.string :credential_id, null: false
      t.text :public_key, null: false
      t.bigint :sign_count, null: false, default: 0

      t.timestamps
    end

    add_index :restore_credentials, :credential_id, unique: true
  end
end
