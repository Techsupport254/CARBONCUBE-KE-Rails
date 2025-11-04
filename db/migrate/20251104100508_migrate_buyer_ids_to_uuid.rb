class MigrateBuyerIdsToUuid < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # Step 1: Add UUID column to buyers table
    puts "Adding UUID column to buyers table..."
    unless column_exists?(:buyers, :uuid)
      add_column :buyers, :uuid, :uuid, default: "gen_random_uuid()", null: false
    end
    unless index_name_exists?(:buyers, 'index_buyers_on_uuid')
      add_index :buyers, :uuid, unique: true, algorithm: :concurrently
    end

    # Step 2: Generate UUIDs for existing buyers
    puts "Generating UUIDs for existing buyers..."
    execute <<-SQL
      UPDATE buyers SET uuid = gen_random_uuid() WHERE uuid IS NULL;
    SQL

    # Step 3: Add UUID columns to all referencing tables
    puts "Adding UUID columns to referencing tables..."
    
    # Ad_searches table
    unless column_exists?(:ad_searches, :buyer_uuid)
      add_column :ad_searches, :buyer_uuid, :uuid
    end
    unless index_exists?(:ad_searches, :buyer_uuid)
      add_index :ad_searches, :buyer_uuid, algorithm: :concurrently
    end
    
    # Cart_items table
    unless column_exists?(:cart_items, :buyer_uuid)
      add_column :cart_items, :buyer_uuid, :uuid
    end
    unless index_exists?(:cart_items, :buyer_uuid)
      add_index :cart_items, :buyer_uuid, algorithm: :concurrently
    end
    
    # Click_events table
    unless column_exists?(:click_events, :buyer_uuid)
      add_column :click_events, :buyer_uuid, :uuid
    end
    unless index_exists?(:click_events, :buyer_uuid)
      add_index :click_events, :buyer_uuid, algorithm: :concurrently
    end
    
    # Conversations table
    unless column_exists?(:conversations, :buyer_uuid)
      add_column :conversations, :buyer_uuid, :uuid
    end
    unless index_exists?(:conversations, :buyer_uuid)
      add_index :conversations, :buyer_uuid, algorithm: :concurrently
    end
    
    # Reviews table
    unless column_exists?(:reviews, :buyer_uuid)
      add_column :reviews, :buyer_uuid, :uuid
    end
    unless index_exists?(:reviews, :buyer_uuid)
      add_index :reviews, :buyer_uuid, algorithm: :concurrently
    end
    
    # Wish_lists table
    unless column_exists?(:wish_lists, :buyer_uuid)
      add_column :wish_lists, :buyer_uuid, :uuid
    end
    unless index_exists?(:wish_lists, :buyer_uuid)
      add_index :wish_lists, :buyer_uuid, algorithm: :concurrently
    end

    # Step 4: Backfill UUIDs from buyers table
    puts "Backfilling UUIDs in referencing tables..."
    
    # Check if buyers.id is already UUID (migration partially completed)
    buyers_id_is_uuid = ActiveRecord::Base.connection.columns('buyers').find { |c| c.name == 'id' }.sql_type == 'uuid'
    
    if buyers_id_is_uuid
      # buyers.id is already UUID - map using created_at order
      puts "buyers.id is already UUID - mapping using created_at order..."
      
      # Create temporary table for mapping
      execute <<-SQL
        -- Clear invalid UUIDs first
        UPDATE ad_searches SET buyer_uuid = NULL WHERE buyer_uuid NOT IN (SELECT id FROM buyers);
        UPDATE cart_items SET buyer_uuid = NULL WHERE buyer_uuid NOT IN (SELECT id FROM buyers);
        UPDATE click_events SET buyer_uuid = NULL WHERE buyer_uuid NOT IN (SELECT id FROM buyers);
        UPDATE conversations SET buyer_uuid = NULL WHERE buyer_uuid NOT IN (SELECT id FROM buyers);
        UPDATE reviews SET buyer_uuid = NULL WHERE buyer_uuid NOT IN (SELECT id FROM buyers);
        UPDATE wish_lists SET buyer_uuid = NULL WHERE buyer_uuid NOT IN (SELECT id FROM buyers);
        
        -- Create temporary table for mapping
        CREATE TEMP TABLE buyer_mapping AS
        SELECT 
          id as uuid_value,
          ROW_NUMBER() OVER (ORDER BY created_at, id)::bigint as sequential_id
        FROM buyers
        ORDER BY created_at, id;
        
        CREATE INDEX ON buyer_mapping(sequential_id);
      SQL
      
      # Use the temp table in separate statements
      execute <<-SQL
        UPDATE ad_searches SET buyer_uuid = bm.uuid_value
        FROM buyer_mapping bm
        WHERE ad_searches.buyer_id = bm.sequential_id AND ad_searches.buyer_uuid IS NULL;
      SQL
      
      execute <<-SQL
        UPDATE cart_items SET buyer_uuid = bm.uuid_value
        FROM buyer_mapping bm
        WHERE cart_items.buyer_id = bm.sequential_id AND cart_items.buyer_uuid IS NULL;
      SQL
      
      execute <<-SQL
        UPDATE click_events SET buyer_uuid = bm.uuid_value
        FROM buyer_mapping bm
        WHERE click_events.buyer_id = bm.sequential_id AND click_events.buyer_uuid IS NULL;
      SQL
      
      execute <<-SQL
        UPDATE conversations SET buyer_uuid = bm.uuid_value
        FROM buyer_mapping bm
        WHERE conversations.buyer_id = bm.sequential_id AND conversations.buyer_uuid IS NULL;
      SQL
      
      execute <<-SQL
        UPDATE reviews SET buyer_uuid = bm.uuid_value
        FROM buyer_mapping bm
        WHERE reviews.buyer_id = bm.sequential_id AND reviews.buyer_uuid IS NULL;
      SQL
      
      execute <<-SQL
        UPDATE wish_lists SET buyer_uuid = bm.uuid_value
        FROM buyer_mapping bm
        WHERE wish_lists.buyer_id = bm.sequential_id AND wish_lists.buyer_uuid IS NULL;
      SQL
      
      # Drop temp table
      execute <<-SQL
        DROP TABLE IF EXISTS buyer_mapping;
      SQL
      
      puts "Backfill completed using created_at ordering (best-effort mapping)."
    else
      # buyers.id is still bigint, use normal join
      execute <<-SQL
        -- Ad_searches
        UPDATE ad_searches SET buyer_uuid = buyers.uuid
        FROM buyers WHERE ad_searches.buyer_id = buyers.id;
        
        -- Cart_items
        UPDATE cart_items SET buyer_uuid = buyers.uuid
        FROM buyers WHERE cart_items.buyer_id = buyers.id;
        
        -- Click_events
        UPDATE click_events SET buyer_uuid = buyers.uuid
        FROM buyers WHERE click_events.buyer_id = buyers.id;
        
        -- Conversations
        UPDATE conversations SET buyer_uuid = buyers.uuid
        FROM buyers WHERE conversations.buyer_id = buyers.id;
        
        -- Reviews
        UPDATE reviews SET buyer_uuid = buyers.uuid
        FROM buyers WHERE reviews.buyer_id = buyers.id;
        
        -- Wish_lists
        UPDATE wish_lists SET buyer_uuid = buyers.uuid
        FROM buyers WHERE wish_lists.buyer_id = buyers.id;
      SQL
    end

    # Step 5: Drop old foreign key constraints
    puts "Dropping old foreign key constraints..."
    remove_foreign_key :ad_searches, :buyers if foreign_key_exists?(:ad_searches, :buyers)
    remove_foreign_key :cart_items, :buyers if foreign_key_exists?(:cart_items, :buyers)
    remove_foreign_key :click_events, :buyers if foreign_key_exists?(:click_events, :buyers)
    remove_foreign_key :conversations, :buyers if foreign_key_exists?(:conversations, :buyers)
    remove_foreign_key :reviews, :buyers if foreign_key_exists?(:reviews, :buyers)
    remove_foreign_key :wish_lists, :buyers if foreign_key_exists?(:wish_lists, :buyers)

    # Step 6: Make UUID columns NOT NULL where required
    puts "Making UUID columns NOT NULL..."
    change_column_null :cart_items, :buyer_uuid, false
    change_column_null :reviews, :buyer_uuid, false
    # ad_searches, click_events, conversations, wish_lists can remain nullable

    # Step 7: Change buyers primary key to UUID first (before adding FKs)
    puts "Changing buyers.id to UUID..."
    buyers_id_is_uuid_check = ActiveRecord::Base.connection.columns('buyers').find { |c| c.name == 'id' }.sql_type == 'uuid'
    unless buyers_id_is_uuid_check
      migrate_buyers_primary_key
    else
      puts "buyers.id is already UUID, skipping primary key change..."
    end

    # Step 8: Add new foreign key constraints with UUID
    puts "Adding new foreign key constraints with UUID..."
    unless foreign_key_exists?(:ad_searches, column: :buyer_uuid)
      add_foreign_key :ad_searches, :buyers, column: :buyer_uuid, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:cart_items, column: :buyer_uuid)
      add_foreign_key :cart_items, :buyers, column: :buyer_uuid, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:click_events, column: :buyer_uuid)
      add_foreign_key :click_events, :buyers, column: :buyer_uuid, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:conversations, column: :buyer_uuid)
      add_foreign_key :conversations, :buyers, column: :buyer_uuid, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:reviews, column: :buyer_uuid)
      add_foreign_key :reviews, :buyers, column: :buyer_uuid, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:wish_lists, column: :buyer_uuid)
      add_foreign_key :wish_lists, :buyers, column: :buyer_uuid, primary_key: :id, on_delete: :cascade
    end

    # Step 9: Update composite indexes
    puts "Updating composite indexes..."
    update_buyer_composite_indexes

    # Step 10: Drop old bigint columns before renaming
    puts "Dropping old bigint buyer_id columns..."
    execute <<-SQL
      ALTER TABLE ad_searches DROP COLUMN IF EXISTS buyer_id;
      ALTER TABLE cart_items DROP COLUMN IF EXISTS buyer_id;
      ALTER TABLE click_events DROP COLUMN IF EXISTS buyer_id;
      ALTER TABLE conversations DROP COLUMN IF EXISTS buyer_id;
      ALTER TABLE reviews DROP COLUMN IF EXISTS buyer_id;
      ALTER TABLE wish_lists DROP COLUMN IF EXISTS buyer_id;
    SQL

    # Step 11: Rename UUID columns to original names
    puts "Renaming UUID columns to original names..."
    rename_column :ad_searches, :buyer_uuid, :buyer_id
    rename_column :cart_items, :buyer_uuid, :buyer_id
    rename_column :click_events, :buyer_uuid, :buyer_id
    rename_column :conversations, :buyer_uuid, :buyer_id
    rename_column :reviews, :buyer_uuid, :buyer_id
    rename_column :wish_lists, :buyer_uuid, :buyer_id

    # Step 12: Update foreign key constraints to use renamed columns
    puts "Updating foreign key constraints..."
    # Drop old FKs (they reference buyer_uuid)
    remove_foreign_key :ad_searches, column: :buyer_uuid if foreign_key_exists?(:ad_searches, column: :buyer_uuid)
    remove_foreign_key :cart_items, column: :buyer_uuid if foreign_key_exists?(:cart_items, column: :buyer_uuid)
    remove_foreign_key :click_events, column: :buyer_uuid if foreign_key_exists?(:click_events, column: :buyer_uuid)
    remove_foreign_key :conversations, column: :buyer_uuid if foreign_key_exists?(:conversations, column: :buyer_uuid)
    remove_foreign_key :reviews, column: :buyer_uuid if foreign_key_exists?(:reviews, column: :buyer_uuid)
    remove_foreign_key :wish_lists, column: :buyer_uuid if foreign_key_exists?(:wish_lists, column: :buyer_uuid)
    
    # Add FKs with correct column names (now buyers.id is UUID)
    add_foreign_key :ad_searches, :buyers, column: :buyer_id, on_delete: :cascade
    add_foreign_key :cart_items, :buyers, column: :buyer_id, on_delete: :cascade
    add_foreign_key :click_events, :buyers, column: :buyer_id, on_delete: :cascade
    add_foreign_key :conversations, :buyers, column: :buyer_id, on_delete: :cascade
    add_foreign_key :reviews, :buyers, column: :buyer_id, on_delete: :cascade
    add_foreign_key :wish_lists, :buyers, column: :buyer_id, on_delete: :cascade

    # Step 13: Update indexes to use correct column names
    puts "Updating indexes to use correct column names..."
    update_buyer_index_names

    # Step 14: Remove sequence reference from buyers table
    puts "Removing sequence reference from buyers table..."
    execute <<-SQL
      ALTER TABLE buyers ALTER COLUMN id DROP DEFAULT;
    SQL

    puts "Migration completed successfully!"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot reverse UUID migration automatically"
  end

  private

  def migrate_buyers_primary_key
    # Change buyers primary key from bigint to UUID
    execute <<-SQL
      -- Drop the primary key constraint by finding its actual name
      DO $$
      DECLARE
        pk_constraint_name text;
      BEGIN
        -- Find the primary key constraint name
        SELECT conname INTO pk_constraint_name
        FROM pg_constraint
        WHERE conrelid = 'buyers'::regclass
        AND contype = 'p'
        LIMIT 1;
        
        -- Drop it if it exists (with CASCADE to handle dependent objects)
        IF pk_constraint_name IS NOT NULL THEN
          EXECUTE format('ALTER TABLE buyers DROP CONSTRAINT %I CASCADE', pk_constraint_name);
        END IF;
      END $$;
      
      -- Rename old id column to old_id
      ALTER TABLE buyers RENAME COLUMN id TO old_id;
      
      -- Rename uuid column to id (this becomes the new primary key)
      ALTER TABLE buyers RENAME COLUMN uuid TO id;
      
      -- Make id (now UUID) the primary key
      ALTER TABLE buyers ADD PRIMARY KEY (id);
      
      -- Drop any foreign keys that might depend on old_id
      DO $$
      DECLARE
        fk_record RECORD;
      BEGIN
        FOR fk_record IN 
          SELECT conname, conrelid::regclass::text as table_name
          FROM pg_constraint
          WHERE confrelid = 'buyers'::regclass
          AND contype = 'f'
          AND confkey @> ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid = 'buyers'::regclass AND attname = 'old_id')]
        LOOP
          EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', fk_record.table_name, fk_record.conname);
        END LOOP;
      END $$;
      
      -- Drop old_id column (no longer needed)
      ALTER TABLE buyers DROP COLUMN old_id CASCADE;
    SQL
  end

  def update_buyer_composite_indexes
    # Update composite indexes that include buyer_id
    execute <<-SQL
      -- Update conversations unique index (includes buyer_id)
      DROP INDEX IF EXISTS index_conversations_on_all_participants_and_ad;
      CREATE UNIQUE INDEX IF NOT EXISTS index_conversations_on_all_participants_and_ad_uuid 
        ON conversations (ad_id, buyer_uuid, seller_id, inquirer_seller_id);
    SQL
  end

  def update_buyer_index_names
    # Rename indexes after columns have been renamed from buyer_uuid to buyer_id
    execute <<-SQL
      -- Rename conversations index to match new column names
      ALTER INDEX IF EXISTS index_conversations_on_all_participants_and_ad_uuid 
        RENAME TO index_conversations_on_all_participants_and_ad;
    SQL
  end
end

