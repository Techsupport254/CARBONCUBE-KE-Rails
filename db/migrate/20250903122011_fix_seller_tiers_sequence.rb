class FixSellerTiersSequence < ActiveRecord::Migration[7.1]
  def up
    # Create the correct sequence for seller_tiers if it doesn't exist
    execute <<-SQL
      CREATE SEQUENCE IF NOT EXISTS seller_tiers_id_seq;
    SQL
    
    # Set the sequence as the default for the id column
    execute <<-SQL
      ALTER TABLE seller_tiers ALTER COLUMN id SET DEFAULT nextval('seller_tiers_id_seq');
    SQL
    
    # Set the sequence to start from the current maximum id + 1
    execute <<-SQL
      SELECT setval('seller_tiers_id_seq', COALESCE((SELECT MAX(id) FROM seller_tiers), 0) + 1);
    SQL
  end

  def down
    # Revert to the original sequence
    execute <<-SQL
      ALTER TABLE seller_tiers ALTER COLUMN id SET DEFAULT nextval('vendor_tiers_id_seq');
    SQL
  end
end
