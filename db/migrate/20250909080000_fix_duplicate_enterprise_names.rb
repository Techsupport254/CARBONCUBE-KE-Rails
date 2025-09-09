class FixDuplicateEnterpriseNames < ActiveRecord::Migration[8.0]
  def up
    # Find all duplicate enterprise names (case insensitive)
    duplicates = execute(<<-SQL)
      SELECT LOWER(enterprise_name) as name, COUNT(*) as count
      FROM sellers 
      WHERE deleted = false
      GROUP BY LOWER(enterprise_name)
      HAVING COUNT(*) > 1
    SQL

    duplicates.each do |row|
      name = row['name']
      count = row['count']
      
      puts "Processing #{count} sellers with name: #{name}"
      
      # Get all sellers with this name, ordered by ID
      sellers = Seller.where('LOWER(enterprise_name) = ? AND deleted = false', name).order(:id)
      
      # Keep the first one unchanged, append ID to the rest
      sellers.offset(1).each do |seller|
        original_name = seller.enterprise_name
        new_name = "#{original_name}-#{seller.id}"
        seller.update!(enterprise_name: new_name)
        puts "Updated seller ID #{seller.id}: '#{original_name}' -> '#{new_name}'"
      end
    end

    puts "Duplicate resolution completed!"
  end

  def down
    # This migration is not easily reversible
    # If needed, you would need to manually restore the original names
    raise ActiveRecord::IrreversibleMigration
  end
end
