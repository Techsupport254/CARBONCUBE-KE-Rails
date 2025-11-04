class MigrateSalesUserIdsToUuid < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # Step 1: Add UUID column to sales_users table
    puts "Adding UUID column to sales_users table..."
    unless column_exists?(:sales_users, :uuid)
      add_column :sales_users, :uuid, :uuid, default: "gen_random_uuid()", null: false
    end
    unless index_name_exists?(:sales_users, 'index_sales_users_on_uuid')
      add_index :sales_users, :uuid, unique: true, algorithm: :concurrently
    end

    # Step 2: Generate UUIDs for existing sales_users
    puts "Generating UUIDs for existing sales_users..."
    execute <<-SQL
      UPDATE sales_users SET uuid = gen_random_uuid() WHERE uuid IS NULL;
    SQL

    # Step 3: No referencing tables found - sales_users has no foreign key dependencies
    puts "No referencing tables found for sales_users."

    # Step 4: Change sales_users primary key to UUID
    puts "Changing sales_users.id to UUID..."
    sales_users_id_is_uuid_check = ActiveRecord::Base.connection.columns('sales_users').find { |c| c.name == 'id' }.sql_type == 'uuid'
    unless sales_users_id_is_uuid_check
      migrate_sales_users_primary_key
    else
      puts "sales_users.id is already UUID, skipping primary key change..."
    end

    puts "Migration completed successfully!"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot reverse UUID migration automatically"
  end

  private

  def migrate_sales_users_primary_key
    # Change sales_users primary key from bigint to UUID
    execute <<-SQL
      -- Drop the primary key constraint by finding its actual name
      DO $$
      DECLARE
        pk_constraint_name text;
      BEGIN
        -- Find the primary key constraint name
        SELECT conname INTO pk_constraint_name
        FROM pg_constraint
        WHERE conrelid = 'sales_users'::regclass
        AND contype = 'p'
        LIMIT 1;
        
        -- Drop it if it exists (with CASCADE to handle dependent objects)
        IF pk_constraint_name IS NOT NULL THEN
          EXECUTE format('ALTER TABLE sales_users DROP CONSTRAINT %I CASCADE', pk_constraint_name);
        END IF;
      END $$;
      
      -- Rename old id column to old_id
      ALTER TABLE sales_users RENAME COLUMN id TO old_id;
      
      -- Rename uuid column to id (this becomes the new primary key)
      ALTER TABLE sales_users RENAME COLUMN uuid TO id;
      
      -- Make id (now UUID) the primary key
      ALTER TABLE sales_users ADD PRIMARY KEY (id);
      
      -- Drop old_id column (no longer needed)
      ALTER TABLE sales_users DROP COLUMN old_id CASCADE;
    SQL
  end
end

