namespace :geocoding do
  desc "Clean up coarse geocoded fallbacks and update location precision for existing records (100% dynamic)"
  task cleanup_coarse_fallbacks: :environment do
    puts "Starting dynamic cleanup of coarse geocoded seller branches..."
    updated_count = 0
    coarse_flagged = 0

    # Dynamically find coordinates shared by multiple sellers (indicates regional/sub-county centroids)
    shared_centroid_threshold = 2
    clustered_coords = Branch
      .where.not(latitude: nil, longitude: nil)
      .group("ROUND(latitude::numeric, 3), ROUND(longitude::numeric, 3)")
      .having("COUNT(DISTINCT seller_id) >= ?", shared_centroid_threshold)
      .pluck(Arel.sql("ROUND(latitude::numeric, 3), ROUND(longitude::numeric, 3)"))

    clustered_set = Set.new(clustered_coords.map { |lat, lon| [lat.to_f, lon.to_f] })
    puts "Dynamically detected #{clustered_set.size} shared regional centroid coordinate clusters."

    Branch.where.not(latitude: nil).find_each do |branch|
      seller = branch.seller
      next unless seller

      rounded_key = [branch.latitude.round(3), branch.longitude.round(3)]
      is_shared_centroid = clustered_set.include?(rounded_key)

      loc = seller.location.to_s.strip
      specific_keywords = %w[godown building plot house shop suite room floor road avenue street estate mall plaza tower complex center centre opp opposite near adjacent]
      has_specific_address = specific_keywords.any? { |kw| loc.downcase.include?(kw) }

      new_precision = if is_shared_centroid
                        coarse_flagged += 1
                        'sub_county'
                      elsif has_specific_address && branch.location_precision == 'exact'
                        'exact'
                      elsif loc.blank?
                        'county'
                      else
                        has_specific_address ? 'exact' : 'sub_county'
                      end

      if branch.location_precision != new_precision
        branch.update_column(:location_precision, new_precision)
        updated_count += 1
      end
    end

    puts "Completed dynamic precision cleanup."
    puts " - Updated #{updated_count} branches with appropriate precision tags."
    puts " - Dynamically identified #{coarse_flagged} branches on shared regional centroids as 'sub_county'."
  end

  desc "Re-geocode imprecise/approximate sellers with strict street-level matching"
  task regeocode_imprecise: :environment do
    puts "Starting dynamic re-geocoding for imprecise/approximate seller branches..."
    imprecise_branches = Branch.where(location_precision: ['sub_county', 'county', 'approximate', nil])
    puts "Found #{imprecise_branches.count} branches needing precise geocoding re-evaluation."

    success_count = 0

    imprecise_branches.find_each do |branch|
      seller = branch.seller
      next unless seller && seller.location.present?

      result = GeocodeSellersJob.new.send(:geocode_location, seller, sync: true)

      if result && result[:precision] == 'exact'
        branch.update(
          latitude: result[:lat],
          longitude: result[:lon],
          location_precision: 'exact'
        )
        puts "Refined coordinates for #{seller.enterprise_name}: (#{result[:lat]}, #{result[:lon]}) -> exact"
        success_count += 1
      end
    end

    puts "Re-geocoding completed. Upgraded #{success_count} branches to exact verified pins."
  end
end
