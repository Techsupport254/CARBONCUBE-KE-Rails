namespace :geocoding do
  desc "Re-geocode ALL sellers from their physical addresses from scratch"
  task regeocode_all: :environment do
    GeocodeAllSellersService.call(force: true)
  end
end
