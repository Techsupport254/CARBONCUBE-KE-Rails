class FixPurchasersIdSequence < ActiveRecord::Migration[7.1]
  def up
    # Ensure the purchasers_id_seq sequence exists (it should from the buyers table definition)
    execute <<-SQL
      CREATE SEQUENCE IF NOT EXISTS purchasers_id_seq;
    SQL
    
    # Set the sequence as the default for the buyers id column (should already be set, but ensure it)
    execute <<-SQL
      ALTER TABLE buyers ALTER COLUMN id SET DEFAULT nextval('purchasers_id_seq');
    SQL
    
    # Set the sequence to start from the current maximum id + 1
    # This fixes the issue where the sequence was out of sync with existing records
    execute <<-SQL
      SELECT setval('purchasers_id_seq', COALESCE((SELECT MAX(id) FROM buyers), 0) + 1, false);
    SQL
  end

  def down
    # No need to revert as this is fixing a sync issue
    # The sequence will remain as purchasers_id_seq (the original name)
  end
end

