class CleanupNonKenyanLocations < ActiveRecord::Migration[7.1]
  def up
    # List of non-Kenyan cities to clean up
    non_kenyan_cities = [
      'Amsterdam',
      'Budapest',
      'Dar Es Salaam',
      'Frankfurt',
      'Johannesburg',
      'Madrid',
      'Marseille',
      'Milan',
      'Munich',
      'Prague'
    ]

    # Update sellers with non-Kenyan cities
    # If they have a valid county_id, set city to county name
    # Otherwise, set city to nil
    Seller.where(city: non_kenyan_cities).find_each do |seller|
      if seller.county_id.present?
        seller.update(city: seller.county&.name)
      else
        seller.update(city: nil)
      end
    end

    # Also clean up city variations (case sensitivity, extra spaces)
    Seller.where('LOWER(city) IN (?)', non_kenyan_cities.map(&:downcase)).find_each do |seller|
      if seller.county_id.present?
        seller.update(city: seller.county&.name)
      else
        seller.update(city: nil)
      end
    end
  end

  def down
    # This migration is destructive, so we can't easily rollback
    raise ActiveRecord::IrreversibleMigration
  end
end
