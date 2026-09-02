# frozen_string_literal: true

namespace :google_place_reviews do
  desc 'Re-validate existing Google Place reviews and remove mismatched ones'
  task cleanup: :environment do
    sellers = Seller.where('jsonb_array_length(google_place_reviews) > 0')
    puts "Checking #{sellers.count} sellers with Google Place reviews..."

    cleared = 0
    kept = 0
    failed = 0

    sellers.find_each do |seller|
      begin
        before = seller.google_place_reviews.size
        GooglePlaceReviewService.new(seller).sync!
        after = seller.reload.google_place_reviews.size

        if after.zero? && before.positive?
          cleared += 1
          puts "CLEARED: #{seller.enterprise_name} (#{seller.id})"
        elsif after.positive?
          kept += 1
          puts "KEPT:    #{seller.enterprise_name} (#{seller.id}) — #{after} reviews"
        else
          kept += 1
        end
      rescue StandardError => e
        failed += 1
        puts "FAILED:  #{seller.enterprise_name} (#{seller.id}): #{e.message}"
      end
    end

    puts "Done. Cleared: #{cleared}, Kept: #{kept}, Failed: #{failed}"
  end
end
