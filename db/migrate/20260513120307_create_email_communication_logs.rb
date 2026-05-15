class CreateEmailCommunicationLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :email_communication_logs, id: :uuid do |t|
      t.references :seller, null: false, foreign_key: true, type: :uuid
      t.string :email_type, null: false
      t.string :message_id
      t.boolean :sent_successfully, default: false
      t.text :error_message
      t.datetime :sent_at

      t.timestamps
    end

    add_index :email_communication_logs, [:seller_id, :email_type], unique: true
  end
end
