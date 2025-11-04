class ChangeSenderIdToUuidInMessages < ActiveRecord::Migration[7.1]
  def up
    # Check if messages.conversation_id is already UUID (conversations migration has run)
    messages_conversation_id_type = ActiveRecord::Base.connection.columns('messages').find { |c| c.name == 'conversation_id' }&.sql_type
    
    # Check if sender_id is already UUID
    sender_id_type = ActiveRecord::Base.connection.columns('messages').find { |c| c.name == 'sender_id' }&.sql_type
    
    if sender_id_type == 'uuid'
      puts "messages.sender_id is already UUID, skipping migration..."
      return
    end
    
    # If conversations haven't been migrated yet, messages will be deleted anyway
    # So we can just delete all messages and convert the column
    if messages_conversation_id_type != 'uuid'
      puts "conversations.id is still bigint - messages will be deleted when conversations migrate."
      puts "Deleting all messages now and converting sender_id to UUID..."
      execute "DELETE FROM messages"
    else
      # Conversations have been migrated, so we need to map existing sender_ids
      puts "Mapping sender_id from bigint to UUID..."
      
      # First, remove any invalid messages with sender_id = 0
      execute "DELETE FROM messages WHERE sender_id = 0"
      
      # Map sender_id based on sender_type
      execute <<-SQL
        UPDATE messages
        SET sender_id = (
          CASE sender_type
            WHEN 'Buyer' THEN (SELECT id::text FROM buyers WHERE id::text = messages.sender_id::text LIMIT 1)
            WHEN 'Seller' THEN (SELECT id::text FROM sellers WHERE id::text = messages.sender_id::text LIMIT 1)
            WHEN 'Admin' THEN (SELECT id::text FROM admins WHERE id::text = messages.sender_id::text LIMIT 1)
            WHEN 'SalesUser' THEN (SELECT id::text FROM sales_users WHERE id::text = messages.sender_id::text LIMIT 1)
            ELSE NULL
          END
        )::uuid
        WHERE sender_id IS NOT NULL;
      SQL
      
      # Delete any messages that couldn't be mapped
      execute "DELETE FROM messages WHERE sender_id::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'"
    end
    
    # Change sender_id from bigint to uuid
    # Since all messages are deleted or mapped, we can safely convert
    change_column_null :messages, :sender_id, true, nil
    # If table is empty, use NULL in USING clause (like conversations migration)
    # Otherwise, use the mapped UUID values
    if messages_conversation_id_type != 'uuid'
      # Table is empty, use NULL
      execute "ALTER TABLE messages ALTER COLUMN sender_id TYPE uuid USING NULL"
    else
      # Table has data, use mapped values (should already be UUID from the UPDATE above)
      execute "ALTER TABLE messages ALTER COLUMN sender_id TYPE uuid USING sender_id::uuid"
    end
    change_column_null :messages, :sender_id, false
  end

  def down
    # Change back to bigint (losing UUID data)
    change_column_null :messages, :sender_id, true, nil
    change_column :messages, :sender_id, :bigint, using: '0'
    change_column_null :messages, :sender_id, false
  end
end
