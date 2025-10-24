# Offers Seeds
puts "🌟 Creating sample offers..."

# Get a seller for offers (use first available seller or create one)
seller = Seller.first || Seller.create!(
  fullname: 'Marketplace Seller',
  email: 'seller@carboncube-ke.com',
  phone_number: '0712345678',
  password: 'password123',
  password_confirmation: 'password123',
  enterprise_name: 'Carbon Cube Marketplace',
  business_registration_number: 'BN123456'
)

# Black Friday Offer
black_friday_offer = Offer.find_or_create_by(name: 'Black Friday Mega Sale') do |offer|
  offer.assign_attributes(
    description: 'The biggest sale of the year! Up to 70% off on thousands of products.',
    offer_type: 'black_friday',
    status: 'active',
    banner_color: '#000000',
    badge_color: '#ff0000',
    icon_name: 'bolt',
    badge_text: 'BLACK FRIDAY',
    cta_text: 'Shop Now',
    discount_type: 'percentage',
    discount_percentage: 70.0,
    featured: true,
    priority: 100,
    show_on_homepage: true,
    show_badge: true,
    start_time: Time.current,
    end_time: Time.current + 3.days,
    seller: seller
  )
end

# Cyber Monday Offer
cyber_monday_offer = Offer.find_or_create_by(name: 'Cyber Monday Tech Deals') do |offer|
  offer.assign_attributes(
    description: 'Amazing deals on electronics, gadgets, and tech accessories.',
    offer_type: 'cyber_monday',
    status: 'active',
    banner_color: '#1e40af',
    badge_color: '#3b82f6',
    icon_name: 'laptop',
    badge_text: 'CYBER MONDAY',
    cta_text: 'Explore Deals',
    discount_type: 'percentage',
    discount_percentage: 50.0,
    featured: true,
    priority: 90,
    show_on_homepage: true,
    show_badge: true,
    start_time: Time.current + 1.day,
    end_time: Time.current + 2.days,
    seller: seller
  )
end

# Flash Sale Offer
flash_sale_offer = Offer.find_or_create_by(name: 'Flash Sale - Limited Time') do |offer|
  offer.assign_attributes(
    description: 'Limited time offers on selected items. Don\'t miss out!',
    offer_type: 'flash_sale',
    status: 'active',
    banner_color: '#dc2626',
    badge_color: '#fbbf24',
    icon_name: 'bolt',
    badge_text: 'FLASH SALE',
    cta_text: 'Shop Now',
    discount_type: 'percentage',
    discount_percentage: 40.0,
    featured: true,
    priority: 80,
    show_on_homepage: true,
    show_badge: true,
    start_time: Time.current,
    end_time: Time.current + 6.hours,
    seller: seller
  )
end

# Clearance Sale
clearance_offer = Offer.find_or_create_by(name: 'Clearance Sale') do |offer|
  offer.assign_attributes(
    description: 'Clearance items at unbeatable prices. Limited stock available.',
    offer_type: 'clearance',
    status: 'active',
    banner_color: '#7c2d12',
    badge_color: '#f97316',
    icon_name: 'tag',
    badge_text: 'CLEARANCE',
    cta_text: 'View Items',
    discount_type: 'percentage',
    discount_percentage: 60.0,
    featured: true,
    priority: 70,
    show_on_homepage: true,
    show_badge: true,
    start_time: Time.current,
    end_time: Time.current + 7.days,
    seller: seller
  )
end

# Christmas Holiday Offer
christmas_offer = Offer.find_or_create_by(name: 'Christmas Holiday Sale') do |offer|
  offer.assign_attributes(
    description: 'Perfect gifts for the holiday season. Spread joy with great deals!',
    offer_type: 'christmas',
    status: 'scheduled',
    banner_color: '#dc2626',
    badge_color: '#fbbf24',
    icon_name: 'gift',
    badge_text: 'CHRISTMAS',
    cta_text: 'Shop Gifts',
    discount_type: 'percentage',
    discount_percentage: 35.0,
    featured: true,
    priority: 85,
    show_on_homepage: true,
    show_badge: true,
    start_time: Time.current + 20.days,
    end_time: Time.current + 30.days,
    seller: seller
  )
end

# New Year Offer
new_year_offer = Offer.find_or_create_by(name: 'New Year Sale') do |offer|
  offer.assign_attributes(
    description: 'Start the new year with amazing deals and fresh beginnings!',
    offer_type: 'new_year',
    status: 'scheduled',
    banner_color: '#1e40af',
    badge_color: '#3b82f6',
    icon_name: 'star',
    badge_text: 'NEW YEAR',
    cta_text: 'Start Fresh',
    discount_type: 'percentage',
    discount_percentage: 25.0,
    featured: true,
    priority: 75,
    show_on_homepage: true,
    show_badge: true,
    start_time: Time.current + 35.days,
    end_time: Time.current + 42.days,
    seller: seller
  )
end

# Valentine's Day Offer
valentines_offer = Offer.find_or_create_by(name: 'Valentine\'s Day Special') do |offer|
  offer.assign_attributes(
    description: 'Show your love with perfect gifts for your special someone.',
    offer_type: 'valentines',
    status: 'scheduled',
    banner_color: '#ec4899',
    badge_color: '#f472b6',
    icon_name: 'heart',
    badge_text: 'VALENTINE\'S',
    cta_text: 'Show Love',
    discount_type: 'percentage',
    discount_percentage: 30.0,
    featured: true,
    priority: 80,
    show_on_homepage: true,
    show_badge: true,
    start_time: Time.current + 70.days,
    end_time: Time.current + 75.days,
    seller: seller
  )
end

# Mother's Day Offer
mothers_day_offer = Offer.find_or_create_by(name: 'Mother\'s Day Special') do |offer|
  offer.assign_attributes(
    description: 'Celebrate the amazing women in your life with thoughtful gifts.',
    offer_type: 'mothers_day',
    status: 'scheduled',
    banner_color: '#7c3aed',
    badge_color: '#a78bfa',
    icon_name: 'heart',
    badge_text: 'MOTHER\'S DAY',
    cta_text: 'Celebrate Mom',
    discount_type: 'percentage',
    discount_percentage: 25.0,
    featured: true,
    priority: 70,
    show_on_homepage: true,
    show_badge: true,
    start_time: Time.current + 160.days,
    end_time: Time.current + 163.days,
    seller: seller
  )
end

# Father's Day Offer
fathers_day_offer = Offer.find_or_create_by(name: 'Father\'s Day Special') do |offer|
  offer.assign_attributes(
    description: 'Honor the fathers and father figures with great gifts.',
    offer_type: 'fathers_day',
    status: 'scheduled',
    banner_color: '#059669',
    badge_color: '#10b981',
    icon_name: 'user',
    badge_text: 'FATHER\'S DAY',
    cta_text: 'Honor Dad',
    discount_type: 'percentage',
    discount_percentage: 25.0,
    featured: true,
    priority: 70,
    show_on_homepage: true,
    show_badge: true,
    start_time: Time.current + 190.days,
    end_time: Time.current + 193.days,
    seller: seller
  )
end

# Independence Day Offer (Kenya)
independence_offer = Offer.find_or_create_by(name: 'Independence Day Sale') do |offer|
  offer.assign_attributes(
    description: 'Celebrate Kenya\'s independence with patriotic deals and offers.',
    offer_type: 'independence_day',
    status: 'scheduled',
    banner_color: '#dc2626',
    badge_color: '#fbbf24',
    icon_name: 'flag',
    badge_text: 'INDEPENDENCE',
    cta_text: 'Celebrate Kenya',
    discount_type: 'percentage',
    discount_percentage: 40.0,
    featured: true,
    priority: 90,
    show_on_homepage: true,
    show_badge: true,
    start_time: Time.current + 11.days,
    end_time: Time.current + 13.days,
    seller: seller
  )
end

# Back to School Offer
back_to_school_offer = Offer.find_or_create_by(name: 'Back to School Sale') do |offer|
  offer.assign_attributes(
    description: 'Get ready for the new school year with essential supplies and deals.',
    offer_type: 'back_to_school',
    status: 'scheduled',
    banner_color: '#059669',
    badge_color: '#10b981',
    icon_name: 'book',
    badge_text: 'BACK TO SCHOOL',
    cta_text: 'Get Ready',
    discount_type: 'percentage',
    discount_percentage: 20.0,
    featured: false,
    priority: 60,
    show_on_homepage: true,
    show_badge: true,
    start_time: Time.current + 300.days,
    end_time: Time.current + 310.days,
    seller: seller
  )
end

puts "✅ Created #{Offer.count} offers:"
puts "   - Black Friday: #{black_friday_offer.name}"
puts "   - Cyber Monday: #{cyber_monday_offer.name}"
puts "   - Flash Sale: #{flash_sale_offer.name}"
puts "   - Clearance: #{clearance_offer.name}"
puts "   - Christmas: #{christmas_offer.name}"
puts "   - New Year: #{new_year_offer.name}"
puts "   - Valentine's Day: #{valentines_offer.name}"
puts "   - Mother's Day: #{mothers_day_offer.name}"
puts "   - Father's Day: #{fathers_day_offer.name}"
puts "   - Independence Day: #{independence_offer.name}"
puts "   - Back to School: #{back_to_school_offer.name}"
puts ""
puts "🎯 Offer Types Available:"
Offer.distinct.pluck(:offer_type).each do |type|
  count = Offer.where(offer_type: type).count
  puts "   - #{type.humanize}: #{count} offer(s)"
end
puts ""
puts "📊 Status Distribution:"
Offer.group(:status).count.each do |status, count|
  puts "   - #{status.humanize}: #{count} offer(s)"
end
