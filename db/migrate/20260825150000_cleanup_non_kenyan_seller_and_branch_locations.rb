class CleanupNonKenyanSellerAndBranchLocations < ActiveRecord::Migration[7.1]
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
    ].freeze

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
    ].freeze

    # Clean sellers with non-Kenyan cities
    Seller.where('LOWER(city) IN (?)', non_kenyan_cities.map(&:downcase)).find_each do |seller|
      fix_user(seller)
    end

    # Clean sellers with non-Kenyan location substrings
    non_kenyan_patterns.each do |pattern|
      Seller.where('location ILIKE ?', pattern).find_each do |seller|
        fix_user(seller)
      end
    end

    # Clean buyers with non-Kenyan cities
    Buyer.where('LOWER(city) IN (?)', non_kenyan_cities.map(&:downcase)).find_each do |buyer|
      fix_user(buyer)
    end

    # Clean buyers with non-Kenyan location substrings
    non_kenyan_patterns.each do |pattern|
      Buyer.where('location ILIKE ?', pattern).find_each do |buyer|
        fix_user(buyer)
      end
    end

    # Clean branches with non-Kenyan location substrings
    non_kenyan_patterns.each do |pattern|
      Branch.where('location ILIKE ?', pattern).find_each do |branch|
        fix_branch(branch)
      end
    end

    # Always re-run Johannesburg-specific cleanup in case it was missed
    ['%Johannesburg%', '%Cape Town%'].each do |pattern|
      Seller.where('location ILIKE ?', pattern).find_each { |s| fix_user(s) }
      Buyer.where('location ILIKE ?', pattern).find_each { |b| fix_user(b) }
      Branch.where('location ILIKE ?', pattern).find_each { |b| fix_branch(b) }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def fix_user(user)
    if user.county_id.present?
      fallback_city = user.county&.name
      user.update_columns(city: fallback_city, location: "#{fallback_city}, Kenya")
    else
      user.update_columns(city: nil, location: nil)
    end
  end

  def fix_branch(branch)
    if branch.county_id.present?
      parts = []
      parts << branch.sub_county&.name if branch.sub_county_id.present?
      parts << branch.county&.name
      parts << 'Kenya'
      branch.update_columns(location: parts.compact.join(', '))
    else
      branch.update_columns(location: nil)
    end
  end
end
