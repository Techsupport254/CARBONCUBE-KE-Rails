class MigrateSellerIdsToUuid < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # Step 1: Add UUID column to sellers table
    puts "Adding UUID column to sellers table..."
    unless column_exists?(:sellers, :uuid)
      add_column :sellers, :uuid, :uuid, default: "gen_random_uuid()", null: false
    end
    # Check if index exists by name (index_exists? might not work correctly)
    unless index_name_exists?(:sellers, 'index_sellers_on_uuid')
      add_index :sellers, :uuid, unique: true, algorithm: :concurrently
    end

    # Step 2: Generate UUIDs for existing sellers
    puts "Generating UUIDs for existing sellers..."
    execute <<-SQL
      UPDATE sellers SET uuid = gen_random_uuid() WHERE uuid IS NULL;
    SQL

    # Step 3: Add UUID columns to all referencing tables
    puts "Adding UUID columns to referencing tables..."
    
    # Ads table
    unless column_exists?(:ads, :seller_uuid)
      add_column :ads, :seller_uuid, :uuid
    end
    unless index_exists?(:ads, :seller_uuid)
      add_index :ads, :seller_uuid, algorithm: :concurrently
    end
    
    # Categories_sellers join table
    unless column_exists?(:categories_sellers, :seller_uuid)
      add_column :categories_sellers, :seller_uuid, :uuid
    end
    unless index_exists?(:categories_sellers, :seller_uuid)
      add_index :categories_sellers, :seller_uuid, algorithm: :concurrently
    end
    
    # Conversations table (two columns)
    unless column_exists?(:conversations, :seller_uuid)
      add_column :conversations, :seller_uuid, :uuid
    end
    unless column_exists?(:conversations, :inquirer_seller_uuid)
      add_column :conversations, :inquirer_seller_uuid, :uuid
    end
    unless index_exists?(:conversations, :seller_uuid)
      add_index :conversations, :seller_uuid, algorithm: :concurrently
    end
    unless index_exists?(:conversations, :inquirer_seller_uuid)
      add_index :conversations, :inquirer_seller_uuid, algorithm: :concurrently
    end
    
    # Offers table
    unless column_exists?(:offers, :seller_uuid)
      add_column :offers, :seller_uuid, :uuid
    end
    unless index_exists?(:offers, :seller_uuid)
      add_index :offers, :seller_uuid, algorithm: :concurrently
    end
    
    # Payment transactions table
    unless column_exists?(:payment_transactions, :seller_uuid)
      add_column :payment_transactions, :seller_uuid, :uuid
    end
    unless index_exists?(:payment_transactions, :seller_uuid)
      add_index :payment_transactions, :seller_uuid, algorithm: :concurrently
    end
    
    # Seller documents table
    unless column_exists?(:seller_documents, :seller_uuid)
      add_column :seller_documents, :seller_uuid, :uuid
    end
    unless index_exists?(:seller_documents, :seller_uuid)
      add_index :seller_documents, :seller_uuid, algorithm: :concurrently
    end
    
    # Seller tiers table
    unless column_exists?(:seller_tiers, :seller_uuid)
      add_column :seller_tiers, :seller_uuid, :uuid
    end
    unless index_exists?(:seller_tiers, :seller_uuid)
      add_index :seller_tiers, :seller_uuid, algorithm: :concurrently
    end
    
    # Wish lists table
    unless column_exists?(:wish_lists, :seller_uuid)
      add_column :wish_lists, :seller_uuid, :uuid
    end
    unless index_exists?(:wish_lists, :seller_uuid)
      add_index :wish_lists, :seller_uuid, algorithm: :concurrently
    end

    # Step 4: Backfill UUIDs from sellers table
    puts "Backfilling UUIDs in referencing tables..."
    
    # Check if sellers.id is already UUID (migration partially completed)
    sellers_id_is_uuid = ActiveRecord::Base.connection.columns('sellers').find { |c| c.name == 'id' }.sql_type == 'uuid'
    
    if sellers_id_is_uuid
      # sellers.id is already UUID - we need to map old integer IDs to UUIDs
      # Since sellers.id was renamed from uuid, both sellers.id and sellers.uuid should be UUIDs
      # We'll map based on created_at order (assumes sellers were created sequentially)
      puts "sellers.id is already UUID - mapping using created_at order..."
      
      # Create temporary table for mapping
      execute <<-SQL
        -- Clear invalid UUIDs first
        UPDATE ads SET seller_uuid = NULL WHERE seller_uuid NOT IN (SELECT id FROM sellers);
        UPDATE categories_sellers SET seller_uuid = NULL WHERE seller_uuid NOT IN (SELECT id FROM sellers);
        UPDATE conversations SET seller_uuid = NULL WHERE seller_uuid NOT IN (SELECT id FROM sellers);
        UPDATE conversations SET inquirer_seller_uuid = NULL WHERE inquirer_seller_uuid NOT IN (SELECT id FROM sellers);
        UPDATE offers SET seller_uuid = NULL WHERE seller_uuid NOT IN (SELECT id FROM sellers);
        UPDATE payment_transactions SET seller_uuid = NULL WHERE seller_uuid NOT IN (SELECT id FROM sellers);
        UPDATE seller_documents SET seller_uuid = NULL WHERE seller_uuid NOT IN (SELECT id FROM sellers);
        UPDATE seller_tiers SET seller_uuid = NULL WHERE seller_uuid NOT IN (SELECT id FROM sellers);
        UPDATE wish_lists SET seller_uuid = NULL WHERE seller_uuid NOT IN (SELECT id FROM sellers);
        
        -- Create temporary table for mapping
        CREATE TEMP TABLE seller_mapping AS
        SELECT 
          id as uuid_value,
          ROW_NUMBER() OVER (ORDER BY created_at, id)::bigint as sequential_id
        FROM sellers
        ORDER BY created_at, id;
        
        CREATE INDEX ON seller_mapping(sequential_id);
      SQL
      
      # Use the temp table in separate statements
      execute <<-SQL
        UPDATE ads SET seller_uuid = sm.uuid_value
        FROM seller_mapping sm
        WHERE ads.seller_id = sm.sequential_id AND ads.seller_uuid IS NULL;
      SQL
      
      execute <<-SQL
        UPDATE categories_sellers SET seller_uuid = sm.uuid_value
        FROM seller_mapping sm
        WHERE categories_sellers.seller_id = sm.sequential_id AND categories_sellers.seller_uuid IS NULL;
      SQL
      
      execute <<-SQL
        UPDATE conversations SET seller_uuid = sm.uuid_value
        FROM seller_mapping sm
        WHERE conversations.seller_id = sm.sequential_id AND conversations.seller_uuid IS NULL;
      SQL
      
      execute <<-SQL
        UPDATE conversations SET inquirer_seller_uuid = sm.uuid_value
        FROM seller_mapping sm
        WHERE conversations.inquirer_seller_id = sm.sequential_id AND conversations.inquirer_seller_uuid IS NULL;
      SQL
      
      execute <<-SQL
        UPDATE offers SET seller_uuid = sm.uuid_value
        FROM seller_mapping sm
        WHERE offers.seller_id = sm.sequential_id AND offers.seller_uuid IS NULL;
      SQL
      
      execute <<-SQL
        UPDATE payment_transactions SET seller_uuid = sm.uuid_value
        FROM seller_mapping sm
        WHERE payment_transactions.seller_id = sm.sequential_id AND payment_transactions.seller_uuid IS NULL;
      SQL
      
      execute <<-SQL
        UPDATE seller_documents SET seller_uuid = sm.uuid_value
        FROM seller_mapping sm
        WHERE seller_documents.seller_id = sm.sequential_id AND seller_documents.seller_uuid IS NULL;
      SQL
      
      execute <<-SQL
        UPDATE seller_tiers SET seller_uuid = sm.uuid_value
        FROM seller_mapping sm
        WHERE seller_tiers.seller_id = sm.sequential_id AND seller_tiers.seller_uuid IS NULL;
      SQL
      
      execute <<-SQL
        UPDATE wish_lists SET seller_uuid = sm.uuid_value
        FROM seller_mapping sm
        WHERE wish_lists.seller_id = sm.sequential_id AND wish_lists.seller_uuid IS NULL;
      SQL
      
      # Drop temp table
      execute <<-SQL
        DROP TABLE IF EXISTS seller_mapping;
      SQL
      
      puts "Backfill completed using created_at ordering (best-effort mapping)."
    else
      # sellers.id is still bigint, use normal join
      execute <<-SQL
        -- Ads
        UPDATE ads SET seller_uuid = sellers.uuid
        FROM sellers WHERE ads.seller_id = sellers.id;
        
        -- Categories sellers
        UPDATE categories_sellers SET seller_uuid = sellers.uuid
        FROM sellers WHERE categories_sellers.seller_id = sellers.id;
        
        -- Conversations seller_id
        UPDATE conversations SET seller_uuid = sellers.uuid
        FROM sellers WHERE conversations.seller_id = sellers.id;
        
        -- Conversations inquirer_seller_id
        UPDATE conversations SET inquirer_seller_uuid = sellers.uuid
        FROM sellers WHERE conversations.inquirer_seller_id = sellers.id;
        
        -- Offers
        UPDATE offers SET seller_uuid = sellers.uuid
        FROM sellers WHERE offers.seller_id = sellers.id;
        
        -- Payment transactions
        UPDATE payment_transactions SET seller_uuid = sellers.uuid
        FROM sellers WHERE payment_transactions.seller_id = sellers.id;
        
        -- Seller documents
        UPDATE seller_documents SET seller_uuid = sellers.uuid
        FROM sellers WHERE seller_documents.seller_id = sellers.id;
        
        -- Seller tiers
        UPDATE seller_tiers SET seller_uuid = sellers.uuid
        FROM sellers WHERE seller_tiers.seller_id = sellers.id;
        
        -- Wish lists
        UPDATE wish_lists SET seller_uuid = sellers.uuid
        FROM sellers WHERE wish_lists.seller_id = sellers.id;
      SQL
    end

    # Step 5: Migrate JSON field in offers.target_sellers
    puts "Migrating JSON field in offers.target_sellers..."
    migrate_offers_target_sellers_json

    # Step 6: Drop old foreign key constraints
    puts "Dropping old foreign key constraints..."
    remove_foreign_key :ads, :sellers if foreign_key_exists?(:ads, :sellers)
    remove_foreign_key :conversations, :sellers if foreign_key_exists?(:conversations, :sellers)
    remove_foreign_key :conversations, column: :inquirer_seller_id if foreign_key_exists?(:conversations, column: :inquirer_seller_id)
    remove_foreign_key :payment_transactions, :sellers if foreign_key_exists?(:payment_transactions, :sellers)
    remove_foreign_key :seller_documents, :sellers if foreign_key_exists?(:seller_documents, :sellers)
    remove_foreign_key :seller_tiers, :sellers if foreign_key_exists?(:seller_tiers, :sellers)
    remove_foreign_key :wish_lists, :sellers if foreign_key_exists?(:wish_lists, :sellers)

    # Step 7: Handle null UUIDs before making columns NOT NULL
    puts "Handling null UUIDs..."
    # Delete orphaned records - need to handle foreign keys
    execute <<-SQL
      -- Delete dependent records first, then orphaned ads
      DELETE FROM click_events WHERE ad_id IN (SELECT id FROM ads WHERE seller_uuid IS NULL);
      DELETE FROM cart_items WHERE ad_id IN (SELECT id FROM ads WHERE seller_uuid IS NULL);
      DELETE FROM reviews WHERE ad_id IN (SELECT id FROM ads WHERE seller_uuid IS NULL);
      DELETE FROM wish_lists WHERE ad_id IN (SELECT id FROM ads WHERE seller_uuid IS NULL);
      DELETE FROM offer_ads WHERE ad_id IN (SELECT id FROM ads WHERE seller_uuid IS NULL);
      DELETE FROM ads WHERE seller_uuid IS NULL;
      
      -- Delete other orphaned records
      DELETE FROM categories_sellers WHERE seller_uuid IS NULL;
      DELETE FROM offers WHERE seller_uuid IS NULL;
      DELETE FROM payment_transactions WHERE seller_uuid IS NULL;
      DELETE FROM seller_documents WHERE seller_uuid IS NULL;
      DELETE FROM seller_tiers WHERE seller_uuid IS NULL;
    SQL
    
    # Step 7: Make UUID columns NOT NULL
    puts "Making UUID columns NOT NULL..."
    change_column_null :ads, :seller_uuid, false
    change_column_null :categories_sellers, :seller_uuid, false
    change_column_null :offers, :seller_uuid, false
    change_column_null :payment_transactions, :seller_uuid, false
    change_column_null :seller_documents, :seller_uuid, false
    change_column_null :seller_tiers, :seller_uuid, false
    # conversations and wish_lists can remain nullable (they're optional)

    # Step 8: Change sellers primary key to UUID first (before adding FKs)
    # Skip if already UUID
    sellers_id_is_uuid_check = ActiveRecord::Base.connection.columns('sellers').find { |c| c.name == 'id' }.sql_type == 'uuid'
    unless sellers_id_is_uuid_check
      puts "Changing sellers.id to UUID..."
      migrate_sellers_primary_key
    else
      puts "sellers.id is already UUID, skipping primary key change..."
    end

    # Step 9: Add new foreign key constraints with UUID
    puts "Adding new foreign key constraints with UUID..."
    unless foreign_key_exists?(:ads, column: :seller_uuid)
      add_foreign_key :ads, :sellers, column: :seller_uuid, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:payment_transactions, column: :seller_uuid)
      add_foreign_key :payment_transactions, :sellers, column: :seller_uuid, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:seller_documents, column: :seller_uuid)
      add_foreign_key :seller_documents, :sellers, column: :seller_uuid, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:seller_tiers, column: :seller_uuid)
      add_foreign_key :seller_tiers, :sellers, column: :seller_uuid, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:wish_lists, column: :seller_uuid)
      add_foreign_key :wish_lists, :sellers, column: :seller_uuid, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:conversations, column: :seller_uuid)
      add_foreign_key :conversations, :sellers, column: :seller_uuid, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:conversations, column: :inquirer_seller_uuid)
      add_foreign_key :conversations, :sellers, column: :inquirer_seller_uuid, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:offers, column: :seller_uuid)
      add_foreign_key :offers, :sellers, column: :seller_uuid, primary_key: :id, on_delete: :cascade
    end

    # Step 10: Update composite indexes
    puts "Updating composite indexes..."
    update_composite_indexes

    # Step 11: Drop old bigint/integer columns before renaming
    puts "Dropping old bigint/integer seller_id columns..."
    execute <<-SQL
      -- Drop old columns (they're no longer needed after UUID columns are populated)
      ALTER TABLE ads DROP COLUMN IF EXISTS seller_id;
      ALTER TABLE categories_sellers DROP COLUMN IF EXISTS seller_id;
      ALTER TABLE conversations DROP COLUMN IF EXISTS seller_id;
      ALTER TABLE conversations DROP COLUMN IF EXISTS inquirer_seller_id;
      ALTER TABLE offers DROP COLUMN IF EXISTS seller_id;
      ALTER TABLE payment_transactions DROP COLUMN IF EXISTS seller_id;
      ALTER TABLE seller_documents DROP COLUMN IF EXISTS seller_id;
      ALTER TABLE seller_tiers DROP COLUMN IF EXISTS seller_id;
      ALTER TABLE wish_lists DROP COLUMN IF EXISTS seller_id;
    SQL

    # Step 12: Rename UUID columns to original names
    puts "Renaming UUID columns to original names..."
    rename_column :ads, :seller_uuid, :seller_id
    rename_column :categories_sellers, :seller_uuid, :seller_id
    rename_column :conversations, :seller_uuid, :seller_id
    rename_column :conversations, :inquirer_seller_uuid, :inquirer_seller_id
    rename_column :offers, :seller_uuid, :seller_id
    rename_column :payment_transactions, :seller_uuid, :seller_id
    rename_column :seller_documents, :seller_uuid, :seller_id
    rename_column :seller_tiers, :seller_uuid, :seller_id
    rename_column :wish_lists, :seller_uuid, :seller_id

    # Step 13: Update foreign key constraints to use renamed columns
    puts "Updating foreign key constraints..."
    # Drop old FKs (they reference seller_uuid)
    remove_foreign_key :ads, column: :seller_uuid if foreign_key_exists?(:ads, column: :seller_uuid)
    remove_foreign_key :payment_transactions, column: :seller_uuid if foreign_key_exists?(:payment_transactions, column: :seller_uuid)
    remove_foreign_key :seller_documents, column: :seller_uuid if foreign_key_exists?(:seller_documents, column: :seller_uuid)
    remove_foreign_key :seller_tiers, column: :seller_uuid if foreign_key_exists?(:seller_tiers, column: :seller_uuid)
    remove_foreign_key :wish_lists, column: :seller_uuid if foreign_key_exists?(:wish_lists, column: :seller_uuid)
    remove_foreign_key :conversations, column: :seller_uuid if foreign_key_exists?(:conversations, column: :seller_uuid)
    remove_foreign_key :conversations, column: :inquirer_seller_uuid if foreign_key_exists?(:conversations, column: :inquirer_seller_uuid)
    remove_foreign_key :offers, column: :seller_uuid if foreign_key_exists?(:offers, column: :seller_uuid)
    
    # Add FKs with correct column names (now sellers.id is UUID)
    add_foreign_key :ads, :sellers, column: :seller_id, on_delete: :cascade
    add_foreign_key :payment_transactions, :sellers, column: :seller_id, on_delete: :cascade
    add_foreign_key :seller_documents, :sellers, column: :seller_id, on_delete: :cascade
    add_foreign_key :seller_tiers, :sellers, column: :seller_id, on_delete: :cascade
    add_foreign_key :wish_lists, :sellers, column: :seller_id, on_delete: :cascade
    add_foreign_key :conversations, :sellers, column: :seller_id, on_delete: :cascade
    add_foreign_key :conversations, :sellers, column: :inquirer_seller_id, on_delete: :cascade
    add_foreign_key :offers, :sellers, column: :seller_id, on_delete: :cascade

    # Step 14: Update indexes to use correct column names
    puts "Updating indexes to use correct column names..."
    update_index_names

    # Step 15: Remove sequence reference from sellers table
    puts "Removing sequence reference from sellers table..."
    execute <<-SQL
      ALTER TABLE sellers ALTER COLUMN id DROP DEFAULT;
      -- Note: We don't drop the sequence itself in case it's referenced elsewhere
    SQL

    puts "Migration completed successfully!"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot reverse UUID migration automatically"
  end

  private

  def migrate_offers_target_sellers_json
    # Migrate offers.target_sellers JSON field from integer IDs to UUIDs
    # This must happen before sellers.id is changed to UUID
    execute <<-SQL
      UPDATE offers
      SET target_sellers = (
        SELECT COALESCE(json_agg(sellers.uuid), '[]'::json)
        FROM sellers
        WHERE sellers.id::text = ANY(
          SELECT json_array_elements_text(target_sellers::json)
        )
      )
      WHERE target_sellers IS NOT NULL 
        AND json_typeof(target_sellers::json) = 'array'
        AND json_array_length(target_sellers::json) > 0;
    SQL
  end

  def migrate_sellers_primary_key
    # Change sellers primary key from bigint to UUID
    # Strategy: Drop primary key constraint, rename columns, recreate primary key
    
    execute <<-SQL
      -- Drop the primary key constraint by finding its actual name
      DO $$
      DECLARE
        pk_constraint_name text;
      BEGIN
        -- Find the primary key constraint name
        SELECT conname INTO pk_constraint_name
        FROM pg_constraint
        WHERE conrelid = 'sellers'::regclass
        AND contype = 'p'
        LIMIT 1;
        
        -- Drop it if it exists (with CASCADE to handle dependent objects)
        IF pk_constraint_name IS NOT NULL THEN
          EXECUTE format('ALTER TABLE sellers DROP CONSTRAINT %I CASCADE', pk_constraint_name);
        END IF;
      END $$;
      
      -- Rename old id column to old_id
      ALTER TABLE sellers RENAME COLUMN id TO old_id;
      
      -- Rename uuid column to id (this becomes the new primary key)
      ALTER TABLE sellers RENAME COLUMN uuid TO id;
      
      -- Make id (now UUID) the primary key
      ALTER TABLE sellers ADD PRIMARY KEY (id);
      
      -- Drop any foreign keys that might depend on old_id
      DO $$
      DECLARE
        fk_record RECORD;
      BEGIN
        FOR fk_record IN 
          SELECT conname, conrelid::regclass::text as table_name
          FROM pg_constraint
          WHERE confrelid = 'sellers'::regclass
          AND contype = 'f'
          AND confkey @> ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid = 'sellers'::regclass AND attname = 'old_id')]
        LOOP
          EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', fk_record.table_name, fk_record.conname);
        END LOOP;
      END $$;
      
      -- Drop old_id column (no longer needed)
      ALTER TABLE sellers DROP COLUMN old_id CASCADE;
    SQL
  end

  def update_composite_indexes
    # Recreate composite indexes with UUID columns
    # Note: CONCURRENTLY cannot be used inside transaction blocks, so we use regular indexes
    
    # Ads indexes
    execute <<-SQL
      -- Drop old composite indexes if they exist
      DROP INDEX IF EXISTS index_ads_on_seller_deleted_flagged;
      DROP INDEX IF EXISTS index_ads_on_seller_deleted_flagged_perf;
      DROP INDEX IF EXISTS index_ads_on_deleted_flagged_seller_created_at;
      DROP INDEX IF EXISTS index_ads_best_sellers_perf;
      
      -- Recreate with UUID (using seller_uuid temporarily)
      CREATE INDEX IF NOT EXISTS index_ads_on_seller_uuid_deleted_flagged 
        ON ads (seller_uuid, deleted, flagged);
      CREATE INDEX IF NOT EXISTS index_ads_on_deleted_flagged_seller_uuid_created_at 
        ON ads (deleted, flagged, seller_uuid, created_at);
      CREATE INDEX IF NOT EXISTS index_ads_best_sellers_perf_uuid 
        ON ads (deleted, flagged, seller_uuid, created_at, id);
    SQL

    # Categories_sellers composite index
    execute <<-SQL
      DROP INDEX IF EXISTS index_categories_sellers_on_category_id_and_seller_id;
      CREATE INDEX IF NOT EXISTS index_categories_sellers_on_category_id_and_seller_uuid 
        ON categories_sellers (category_id, seller_uuid);
    SQL

    # Conversations unique index
    execute <<-SQL
      DROP INDEX IF EXISTS index_conversations_on_all_participants_and_ad;
      CREATE UNIQUE INDEX IF NOT EXISTS index_conversations_on_all_participants_and_ad_uuid 
        ON conversations (ad_id, buyer_id, seller_uuid, inquirer_seller_uuid);
    SQL

    # Seller_documents unique index
    execute <<-SQL
      DROP INDEX IF EXISTS index_seller_documents_on_seller_id_and_document_type_id;
      CREATE UNIQUE INDEX IF NOT EXISTS index_seller_documents_on_seller_uuid_and_document_type_id 
        ON seller_documents (seller_uuid, document_type_id);
    SQL

    # Seller_tiers composite index
    execute <<-SQL
      DROP INDEX IF EXISTS index_seller_tiers_on_seller_id_tier_id;
      CREATE INDEX IF NOT EXISTS index_seller_tiers_on_seller_uuid_tier_id 
        ON seller_tiers (seller_uuid, tier_id);
    SQL
  end

  def update_index_names
    # Rename indexes after columns have been renamed from seller_uuid to seller_id
    execute <<-SQL
      -- Rename indexes to match new column names
      ALTER INDEX IF EXISTS index_ads_on_seller_uuid_deleted_flagged 
        RENAME TO index_ads_on_seller_deleted_flagged;
      ALTER INDEX IF EXISTS index_ads_on_deleted_flagged_seller_uuid_created_at 
        RENAME TO index_ads_on_deleted_flagged_seller_created_at;
      ALTER INDEX IF EXISTS index_ads_best_sellers_perf_uuid 
        RENAME TO index_ads_best_sellers_perf;
      ALTER INDEX IF EXISTS index_categories_sellers_on_category_id_and_seller_uuid 
        RENAME TO index_categories_sellers_on_category_id_and_seller_id;
      ALTER INDEX IF EXISTS index_conversations_on_all_participants_and_ad_uuid 
        RENAME TO index_conversations_on_all_participants_and_ad;
      ALTER INDEX IF EXISTS index_seller_documents_on_seller_uuid_and_document_type_id 
        RENAME TO index_seller_documents_on_seller_id_and_document_type_id;
      ALTER INDEX IF EXISTS index_seller_tiers_on_seller_uuid_tier_id 
        RENAME TO index_seller_tiers_on_seller_id_tier_id;
    SQL
  end
end

