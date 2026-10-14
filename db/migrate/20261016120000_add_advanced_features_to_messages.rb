class AddAdvancedFeaturesToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :edited_at, :datetime
    add_column :messages, :deleted_for_everyone, :boolean, default: false, null: false
    add_column :messages, :deleted_by_user_ids, :jsonb, default: [], null: false
    add_column :messages, :idempotency_key, :string
    add_column :messages, :media_urls, :jsonb, default: [], null: false
    add_column :messages, :reply_to_message_id, :bigint

    add_index :messages, [:conversation_id, :idempotency_key], unique: true, where: "idempotency_key IS NOT NULL"
    add_index :messages, :reply_to_message_id
  end
end
