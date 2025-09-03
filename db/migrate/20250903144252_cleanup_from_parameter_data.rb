class CleanupFromParameterData < ActiveRecord::Migration[7.0]
  def up
    # Find records where source is set but utm_source is nil/empty
    # These are likely records created with the 'from' parameter
    records_to_update = Analytic.where.not(source: [nil, ''])
                                .where(utm_source: [nil, ''])
    
    puts "Found #{records_to_update.count} records with 'from' parameter data to clean up"
    
    records_to_update.find_each do |record|
      # Move the source value to utm_source
      record.update!(
        utm_source: record.source,
        source: nil
      )
    end
    
    puts "Successfully cleaned up #{records_to_update.count} records"
  end

  def down
    # This migration is not reversible as we're cleaning up data
    # If needed, you would need to restore from a backup
    raise ActiveRecord::IrreversibleMigration
  end
end
