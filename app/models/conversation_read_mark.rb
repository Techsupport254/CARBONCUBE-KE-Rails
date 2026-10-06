# Per-viewer "seen up to" cursor for staff conversation views.
#
# Staff (Admin/SalesUser/MarketingUser) can see conversations they are not a
# participant in. Setting read_at on those messages would change what the
# real participants see, so staff read state lives here instead: a mark row
# means "this viewer has seen this conversation up to last_read_at".
class ConversationReadMark < ApplicationRecord
  belongs_to :conversation
  belongs_to :reader, polymorphic: true

  # Upsert the viewer's cursor. One row per (conversation, reader).
  def self.mark!(reader:, conversation_id:, at: Time.current)
    mark = find_or_initialize_by(reader: reader, conversation_id: conversation_id)
    mark.last_read_at = at
    mark.save!
    mark
  end

  # Bulk upsert marks for many conversations — used by mark_all_read.
  def self.mark_all!(reader:, conversation_ids:, at: Time.current)
    return if conversation_ids.blank?

    rows = conversation_ids.map do |conversation_id|
      {
        conversation_id: conversation_id,
        reader_type: reader.class.name,
        reader_id: reader.id,
        last_read_at: at,
        created_at: at,
        updated_at: at
      }
    end
    upsert_all(rows, unique_by: :index_conversation_read_marks_unique)
  end
end
