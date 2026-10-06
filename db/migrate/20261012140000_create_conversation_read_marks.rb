class CreateConversationReadMarks < ActiveRecord::Migration[7.1]
  # Per-viewer read state for staff (Admin/SalesUser/MarketingUser). Staff can
  # see conversations they are not a participant in (peer-to-peer
  # buyer↔seller threads); marking those "read" must only affect the staff
  # member's own view — setting read_at on the messages would change what the
  # real participants see. A mark row records "this viewer has seen this
  # conversation up to this timestamp".
  def change
    create_table :conversation_read_marks, id: :uuid do |t|
      t.references :conversation, null: false, foreign_key: true, type: :uuid
      t.string :reader_type, null: false
      t.uuid :reader_id, null: false
      t.datetime :last_read_at, null: false
      t.timestamps

      t.index [:conversation_id, :reader_type, :reader_id],
              unique: true,
              name: 'index_conversation_read_marks_unique'
    end
    add_index :conversation_read_marks, [:reader_type, :reader_id]
  end
end
