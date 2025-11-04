class MigrateAdminIdsToUuid < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # Step 1: Add UUID column to admins table
    puts "Adding UUID column to admins table..."
    unless column_exists?(:admins, :uuid)
      add_column :admins, :uuid, :uuid, default: "gen_random_uuid()", null: false
    end
    unless index_name_exists?(:admins, 'index_admins_on_uuid')
      add_index :admins, :uuid, unique: true, algorithm: :concurrently
    end

    # Step 2: Generate UUIDs for existing admins
    puts "Generating UUIDs for existing admins..."
    execute <<-SQL
      UPDATE admins SET uuid = gen_random_uuid() WHERE uuid IS NULL;
    SQL

    # Step 3: Add UUID columns to all referencing tables
    puts "Adding UUID columns to referencing tables..."
    
    # Conversations table
    unless column_exists?(:conversations, :admin_uuid)
      add_column :conversations, :admin_uuid, :uuid
    end
    unless index_exists?(:conversations, :admin_uuid)
      add_index :conversations, :admin_uuid, algorithm: :concurrently
    end
    
    # Issues table (assigned_to_id references admins)
    unless column_exists?(:issues, :assigned_to_uuid)
      add_column :issues, :assigned_to_uuid, :uuid
    end
    unless index_exists?(:issues, :assigned_to_uuid)
      add_index :issues, :assigned_to_uuid, algorithm: :concurrently
    end

    # Step 4: Backfill UUIDs from admins table
    puts "Backfilling UUIDs in referencing tables..."
    
    # Check if admins.id is already UUID
    admins_id_is_uuid = ActiveRecord::Base.connection.columns('admins').find { |c| c.name == 'id' }.sql_type == 'uuid'
    
    if admins_id_is_uuid
      # admins.id is already UUID - map using created_at order
      puts "admins.id is already UUID - mapping using created_at order..."
      execute <<-SQL
        -- Clear invalid UUIDs first
        UPDATE conversations SET admin_uuid = NULL WHERE admin_uuid NOT IN (SELECT id FROM admins);
        UPDATE issues SET assigned_to_uuid = NULL WHERE assigned_to_uuid NOT IN (SELECT id FROM admins);
        
        -- Create mapping based on created_at order
        WITH admin_mapping AS (
          SELECT 
            id as uuid_value,
            ROW_NUMBER() OVER (ORDER BY created_at, id)::bigint as sequential_id
          FROM admins
          ORDER BY created_at, id
        )
        UPDATE conversations SET admin_uuid = am.uuid_value
        FROM admin_mapping am
        WHERE conversations.admin_id = am.sequential_id AND conversations.admin_uuid IS NULL;
        
        UPDATE issues SET assigned_to_uuid = am.uuid_value
        FROM admin_mapping am
        WHERE issues.assigned_to_id = am.sequential_id AND issues.assigned_to_uuid IS NULL;
      SQL
      puts "Backfill completed using created_at ordering (best-effort mapping)."
    else
      # admins.id is still bigint, use normal join
      execute <<-SQL
        -- Conversations
        UPDATE conversations SET admin_uuid = admins.uuid
        FROM admins WHERE conversations.admin_id = admins.id;
        
        -- Issues
        UPDATE issues SET assigned_to_uuid = admins.uuid
        FROM admins WHERE issues.assigned_to_id = admins.id;
      SQL
    end

    # Step 5: Drop old foreign key constraints
    puts "Dropping old foreign key constraints..."
    remove_foreign_key :conversations, :admins if foreign_key_exists?(:conversations, :admins)
    remove_foreign_key :issues, column: :assigned_to_id if foreign_key_exists?(:issues, column: :assigned_to_id)

    # Step 6: Change admins primary key to UUID first (before adding FKs)
    puts "Changing admins.id to UUID..."
    admins_id_is_uuid_check = ActiveRecord::Base.connection.columns('admins').find { |c| c.name == 'id' }.sql_type == 'uuid'
    unless admins_id_is_uuid_check
      migrate_admins_primary_key
    else
      puts "admins.id is already UUID, skipping primary key change..."
    end

    # Step 7: Add new foreign key constraints with UUID
    puts "Adding new foreign key constraints with UUID..."
    unless foreign_key_exists?(:conversations, column: :admin_uuid)
      add_foreign_key :conversations, :admins, column: :admin_uuid, primary_key: :id, on_delete: :cascade
    end
    unless foreign_key_exists?(:issues, column: :assigned_to_uuid)
      add_foreign_key :issues, :admins, column: :assigned_to_uuid, primary_key: :id, on_delete: :cascade
    end

    # Step 8: Update composite indexes
    puts "Updating composite indexes..."
    update_admin_composite_indexes

    # Step 9: Drop old bigint columns before renaming
    puts "Dropping old bigint admin_id columns..."
    execute <<-SQL
      ALTER TABLE conversations DROP COLUMN IF EXISTS admin_id;
      ALTER TABLE issues DROP COLUMN IF EXISTS assigned_to_id;
    SQL

    # Step 10: Rename UUID columns to original names
    puts "Renaming UUID columns to original names..."
    rename_column :conversations, :admin_uuid, :admin_id
    rename_column :issues, :assigned_to_uuid, :assigned_to_id

    # Step 11: Update foreign key constraints to use renamed columns
    puts "Updating foreign key constraints..."
    # Drop old FKs
    remove_foreign_key :conversations, column: :admin_uuid if foreign_key_exists?(:conversations, column: :admin_uuid)
    remove_foreign_key :issues, column: :assigned_to_uuid if foreign_key_exists?(:issues, column: :assigned_to_uuid)
    
    # Add FKs with correct column names (now admins.id is UUID)
    add_foreign_key :conversations, :admins, column: :admin_id, on_delete: :cascade
    add_foreign_key :issues, :admins, column: :assigned_to_id, on_delete: :cascade

    # Step 12: Update indexes to use correct column names
    puts "Updating indexes to use correct column names..."
    update_admin_index_names

    puts "Migration completed successfully!"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot reverse UUID migration automatically"
  end

  private

  def migrate_admins_primary_key
    # Change admins primary key from bigint to UUID
    execute <<-SQL
      -- Drop the primary key constraint by finding its actual name
      DO $$
      DECLARE
        pk_constraint_name text;
      BEGIN
        -- Find the primary key constraint name
        SELECT conname INTO pk_constraint_name
        FROM pg_constraint
        WHERE conrelid = 'admins'::regclass
        AND contype = 'p'
        LIMIT 1;
        
        -- Drop it if it exists (with CASCADE to handle dependent objects)
        IF pk_constraint_name IS NOT NULL THEN
          EXECUTE format('ALTER TABLE admins DROP CONSTRAINT %I CASCADE', pk_constraint_name);
        END IF;
      END $$;
      
      -- Rename old id column to old_id
      ALTER TABLE admins RENAME COLUMN id TO old_id;
      
      -- Rename uuid column to id (this becomes the new primary key)
      ALTER TABLE admins RENAME COLUMN uuid TO id;
      
      -- Make id (now UUID) the primary key
      ALTER TABLE admins ADD PRIMARY KEY (id);
      
      -- Drop any foreign keys that might depend on old_id
      DO $$
      DECLARE
        fk_record RECORD;
      BEGIN
        FOR fk_record IN 
          SELECT conname, conrelid::regclass::text as table_name
          FROM pg_constraint
          WHERE confrelid = 'admins'::regclass
          AND contype = 'f'
          AND confkey @> ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid = 'admins'::regclass AND attname = 'old_id')]
        LOOP
          EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', fk_record.table_name, fk_record.conname);
        END LOOP;
      END $$;
      
      -- Drop old_id column (no longer needed)
      ALTER TABLE admins DROP COLUMN old_id CASCADE;
    SQL
  end

  def update_admin_composite_indexes
    # Update composite indexes that include admin_id
    execute <<-SQL
      -- Update conversations unique index (includes admin_id, buyer_id, seller_id)
      DROP INDEX IF EXISTS index_conversations_on_all_participants_and_ad;
      CREATE UNIQUE INDEX IF NOT EXISTS index_conversations_on_all_participants_and_ad_uuid 
        ON conversations (ad_id, buyer_id, seller_id, inquirer_seller_id, admin_id);
    SQL
  end

  def update_admin_index_names
    # Rename indexes after columns have been renamed
    execute <<-SQL
      -- Rename conversations index to match new column names
      ALTER INDEX IF EXISTS index_conversations_on_all_participants_and_ad_uuid 
        RENAME TO index_conversations_on_all_participants_and_ad;
    SQL
  end
end

