class RestorePrimaryKeys < ActiveRecord::Migration[7.1]
  def up
    # These tables have an 'id' column but the primary key constraint was lost
    # during a pg_dump/restore. This migration re-adds the PRIMARY KEY constraint
    # on each table. It skips any table that already has a PK to be idempotent.

    tables_with_id = connection.tables.select do |t|
      next false if %w[schema_migrations ar_internal_metadata].include?(t)
      connection.columns(t).any? { |c| c.name == "id" }
    end

    tables_with_id.each do |table|
      existing_pk = connection.primary_key(table)
      next if existing_pk.present?

      say "Restoring PRIMARY KEY on #{table}"
      execute "ALTER TABLE #{quote_table_name(table)} ADD PRIMARY KEY (id);"
    rescue => e
      say "Skipping #{table}: #{e.message}"
    end
  end

  def down
    # Reversing this would require dropping PKs which is destructive — not supported.
    raise ActiveRecord::IrreversibleMigration
  end
end
