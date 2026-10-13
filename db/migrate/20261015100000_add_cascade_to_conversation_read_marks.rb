class AddCascadeToConversationReadMarks < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :conversation_read_marks, :conversations
    add_foreign_key :conversation_read_marks, :conversations, on_delete: :cascade
  end
end
