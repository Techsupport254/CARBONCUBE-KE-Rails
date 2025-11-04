class MigrateConversationsIdToUuid < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # Check if conversations.id is already UUID (prevent re-running)
    conversations_id_type = ActiveRecord::Base.connection.columns('conversations').find { |c| c.name == 'id' }&.sql_type
    messages_conversation_id_type = ActiveRecord::Base.connection.columns('messages').find { |c| c.name == 'conversation_id' }&.sql_type
    
    if conversations_id_type == 'uuid' && messages_conversation_id_type == 'uuid'
      puts "conversations.id and messages.conversation_id are already UUID, skipping migration..."
      return
    end
    
    puts "Migrating conversations.id from bigint to UUID..."
    
    # Step 1: Delete all existing conversations (cascade will delete messages)
    # Only delete if conversations.id is still bigint (not already migrated)
    if conversations_id_type != 'uuid'
      puts "Deleting all existing conversations and messages (this will only run once)..."
      execute <<-SQL
        DELETE FROM conversations;
      SQL
      puts "All conversations and messages deleted."
    else
      puts "conversations.id is already UUID, skipping deletion step..."
    end
    
    # Step 2: Drop foreign key constraint from messages to conversations (only if needed)
    if conversations_id_type != 'uuid'
      puts "Dropping foreign key constraint from messages..."
      remove_foreign_key :messages, :conversations if foreign_key_exists?(:messages, :conversations)
    end
    
    # Step 3: Change conversations.id from bigint to uuid (only if not already UUID)
    if conversations_id_type != 'uuid'
      puts "Changing conversations.id to UUID..."
      execute <<-SQL
        -- Drop the primary key constraint
        ALTER TABLE conversations DROP CONSTRAINT conversations_pkey;
        
        -- Drop the default first (can't change type with sequence default)
        ALTER TABLE conversations ALTER COLUMN id DROP DEFAULT;
        
        -- Change the id column type to UUID
        ALTER TABLE conversations ALTER COLUMN id TYPE uuid USING gen_random_uuid();
        
        -- Set default to gen_random_uuid()
        ALTER TABLE conversations ALTER COLUMN id SET DEFAULT gen_random_uuid();
        
        -- Re-add primary key constraint
        ALTER TABLE conversations ADD PRIMARY KEY (id);
      SQL
    else
      puts "conversations.id is already UUID, skipping type change..."
    end
    
    # Step 4: Change messages.conversation_id from bigint to uuid (only if not already UUID)
    if messages_conversation_id_type != 'uuid'
      puts "Changing messages.conversation_id to UUID..."
      # Check if messages table has any rows
      message_count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM messages").first['count'].to_i
      if message_count > 0
        # If there are messages, we need to handle them differently
        # This shouldn't happen if conversations were deleted, but just in case
        puts "WARNING: Messages table has #{message_count} rows. This migration expects an empty table."
        puts "Skipping messages.conversation_id type change. Please ensure messages table is empty."
      else
        # Since messages table is empty, we can use a dummy USING clause
        execute <<-SQL
          ALTER TABLE messages ALTER COLUMN conversation_id TYPE uuid USING NULL;
        SQL
      end
    else
      puts "messages.conversation_id is already UUID, skipping type change..."
    end
    
    # Step 5: Re-add foreign key constraint (only if it doesn't exist)
    unless foreign_key_exists?(:messages, :conversations)
      puts "Re-adding foreign key constraint..."
      add_foreign_key :messages, :conversations, column: :conversation_id, on_delete: :cascade
    else
      puts "Foreign key constraint already exists, skipping..."
    end
    
    # Step 6: Drop the old sequence (no longer needed)
    sequence_exists = ActiveRecord::Base.connection.execute(
      "SELECT EXISTS(SELECT 1 FROM pg_sequences WHERE sequencename = 'conversations_id_seq') as exists"
    ).first['exists']
    
    if sequence_exists
      puts "Dropping old conversations_id_seq sequence..."
      execute <<-SQL
        DROP SEQUENCE IF EXISTS conversations_id_seq CASCADE;
      SQL
    else
      puts "conversations_id_seq sequence doesn't exist, skipping..."
    end
    
    puts "✅ Migration completed: conversations.id is now UUID"
  end

  def down
    # This migration is not easily reversible since we deleted all data
    raise ActiveRecord::IrreversibleMigration, "Cannot reverse UUID migration - data was deleted"
  end
end
