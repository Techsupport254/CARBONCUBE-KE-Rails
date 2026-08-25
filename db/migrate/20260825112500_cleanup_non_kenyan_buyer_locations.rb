class CleanupNonKenyanBuyerLocations < ActiveRecord::Migration[7.1]
  def up
    non_kenyan_cities = [
      'Amsterdam',
      'Atlanta',
      'Barcelona',
      'Berlin',
      'Bordeaux',
      'Boston',
      'Bratislava',
      'Brussels',
      'Budapest',
      'Cape Town',
      'Chennai',
      'Chicago',
      'Copenhagen',
      'Dar Es Salaam',
      'Dublin',
      'Durban',
      'Frankfurt',
      'Geneva',
      'Hamburg',
      'Helsinki',
      'Johannesburg',
      'Lagos',
      'Lisbon',
      'London',
      'Los Angeles',
      'Madrid',
      'Manama',
      'Maputo',
      'Marseille',
      'Miami',
      'Milan',
      'Montreal',
      'Munich',
      'Newark',
      'New York',
      'Oslo',
      'Paris',
      'Prague',
      'Pretoria',
      'Rome',
      'San Francisco',
      'San Jose',
      'Seattle',
      'Singapore',
      'Stockholm',
      'Sydney',
      'Tokyo',
      'Toronto',
      'Vienna',
      'Warsaw',
      'Washington',
      'Zurich'
    ]

    non_kenyan_patterns = [
      '%South Africa%',
      '%Netherlands%',
      '%Nigeria%',
      '%Germany%',
      '%Italy%',
      '%Singapore%',
      '%United Kingdom%',
      '%Mozambique%',
      '%France%',
      '%Switzerland%',
      '%Spain%',
      '%Tanzania%',
      '%Portugal%',
      '%United States%',
      '%Canada%',
      '%Hungary%',
      '%Slovakia%',
      '%India%',
      '%Poland%',
      '%Bahrain%'
    ]

    # Clean up buyers with non-Kenyan cities
    Buyer.where('LOWER(city) IN (?)', non_kenyan_cities.map(&:downcase)).find_each do |buyer|
      if buyer.county_id.present?
        buyer.update_columns(city: buyer.county&.name, location: "#{buyer.county&.name}, Kenya")
      else
        buyer.update_columns(city: nil, location: nil)
      end
    end

    # Clean up buyers with non-Kenyan locations
    non_kenyan_patterns.each do |pattern|
      Buyer.where('location ILIKE ?', pattern).find_each do |buyer|
        if buyer.county_id.present?
          buyer.update_columns(city: buyer.county&.name, location: "#{buyer.county&.name}, Kenya")
        else
          buyer.update_columns(city: nil, location: nil)
        end
      end
    end
  end

  def down
    # Destructive cleanup migration
    raise ActiveRecord::IrreversibleMigration
  end
end
