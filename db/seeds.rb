# This file should ensure the existence of records required to run the application in every environment (adion,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# db/seeds.rb

require 'faker'
require 'set'


puts "Starts seeding..."


# Income ranges
income_ranges = ['0-10000', '10000-20000', '20000-50000', '50000-100000', '100000-500000', '500000+']
income_ranges.each do |range|
  Income.find_or_create_by(range: range)
end

# Sectors
sectors = [
  'Agriculture', 'Automotive', 'Banking', 'Construction', 'Education', 'Energy',
  'Entertainment', 'Fashion', 'Finance', 'Food & Beverage', 'Healthcare',
  'Hospitality', 'Information Technology', 'Manufacturing', 'Media', 'Real Estate',
  'Retail', 'Telecommunications', 'Transportation', 'Travel', 'NGOs', 'Others'
]
sectors.each do |name|
  Sector.find_or_create_by(name: name)
end

# Employment statuses
employment_statuses = ['Student', 'Employed', 'Self-Employed', 'Unemployed', 'Retired']
employment_statuses.each do |status|
  Employment.find_or_create_by(status: status)
end

# Education levels
education_levels = ['Primary', 'High-School', 'Under-Graduate', 'Post-Graduate']
education_levels.each do |level|
  Education.find_or_create_by(level: level)
end


# Age groups
["18-25", "26-35", "36-45", "46-55", "56-65", "65+"].each do |label|
  AgeGroup.find_or_create_by(name: label)
end


# Create categories with descriptions
categories = [
  { name: 'Automotive Parts & Accessories', description: 'Spare parts for automobiles' },
  { name: 'Computer Parts & Accessories', description: 'Components and accessories for computers' },
  { name: 'Filtration', description: 'Ads related to filtration solutions' },
  { name: 'Hardware Tools', description: 'Various Hardware Tools' }
]


# Create or find categories and add subcategories
categories.each do |category_data|
  category = Category.find_or_create_by(name: category_data[:name]) do |c|
    c.description = category_data[:description]
  end

  # Define subcategories based on category name
  case category.name
  when 'Automotive Parts & Accessories'
      subcategories = [
        { name: 'Batteries' },
        { name: 'Lubricants' },
        { name: 'Accessories' },
        { name: 'Spare Parts' },
        { name: 'Tyres' },
        { name: 'Others' }
      ]
  when 'Computer Parts & Accessories'
      subcategories = [
        { name: 'Cooling & Maintenance' },
        { name: 'Internal Components' },
        { name: 'Networking Equipment' },
        { name: 'Peripherals' },
        { name: 'Storage' },
        { name: 'Accessories' },
        { name: 'Others' }
      ]
  when 'Filtration'
      subcategories = [
        { name: 'Air Filters' },
        { name: 'Fuel Filters' },
        { name: 'Industrial Filters' },
        { name: 'Oil & Hydraulic Filters' },
        { name: 'Others' }
      ]
  when 'Hardware Tools'
      subcategories = [
        { name: 'Safety Wear' },
        { name: 'Hand & Power Tools' },
        { name: 'Power & Electrical Equipment' },
        { name: 'Plumbing Supplies' },
        { name: 'Others' }
      ]
  end

  # Create subcategories
  if subcategories
    subcategories.each do |subcategory_data|
      category.subcategories.find_or_create_by(name: subcategory_data[:name])
    end
  end
end

puts "Starts seeding Admin"

# Seed admin data
Admin.find_or_create_by(email: 'admin@example.com') do |admin|
  admin.fullname = 'Admin Name'
  admin.username = 'admin'
  admin.password = 'admin123'
end


# Seed sales user data
SalesUser.find_or_create_by(email: 'sales@example.com') do |sales|
  sales.fullname = 'kimani'
  sales.password = '@kimani123'
end


SalesUser.find_or_create_by(email: 'dennis@carboncube.com') do |sales|
  sales.fullname = 'Dennis Kiplangat'
  sales.password = '@dennis231'
end

SalesUser.find_or_create_by(email: 'timothy@carboncube.com') do |sales|
  sales.fullname = 'Timothy Mwangi'
  sales.password = '@timothy123'
end

puts "Starts seeding Sellers, Riders and Buyers"

# Seed Tiers
free_tier = Tier.create!(name: "Free", ads_limit: 10)
basic_tier = Tier.create!(name: "Basic", ads_limit: 100)
standard_tier = Tier.create!(name: "Standard", ads_limit: 400)
premium_tier = Tier.create!(name: "Premium", ads_limit: 2000) # Unlimited ads

# Seed Features
free_features = [
  "No access to marketplace analytics",
  "No dedicated customer services",
  "No promotional tools",
  "Dedicated technical support"
]
basic_features = [
  "Improved listing visibility",
  "Marketplace analytics access",
  "Ability to create limited discount offers",
  "Dedicated technical support"
]
standard_features = [
  "Priority listing in category searches",
  "Marketplace analytics access",
  "Ability to create discount offers",
  "Dedicated technical support"
]
premium_features = [
  "Featured listing options",
  "Marketplace analytics access",
  "Ability to create discount offers",
  "Advanced promotional tools (banner ads on category pages)",
  "Access to Wishlist Statistics",
  "Access to Competitor Statistics",
  "Ability to Post Product Videos",
  "Inclusive of the physical verification",
  "Dedicated technical support" 
]

# Associate features with tiers
{ free_tier => free_features, basic_tier => basic_features, standard_tier => standard_features, premium_tier => premium_features }.each do |tier, features|
  features.each do |feature|
    TierFeature.create!(tier: tier, feature_name: feature)
  end
end

# Seed Pricing
pricing_data = {
  free_tier => { 1 => 0.00, 3 => 0.00, 6 => 0.00, 12 => 0.00 },
  basic_tier => { 1 => 3000.00, 3 => 8550.00, 6 => 16200.00, 12 => 30600.00 },
  standard_tier => { 1 => 7500.00, 3 => 21375.00, 6 => 40500.00, 12 => 76500.00 },
  premium_tier => { 1 => 15000.00, 3 => 42750.00, 6 => 81000.00, 12 => 153000.00 }
}

# Associate pricing with tiers
pricing_data.each do |tier, prices|
  prices.each do |duration, price|
    TierPricing.create!(tier: tier, duration_months: duration, price: price)
  end
end


# Counties and Sub-Counties data
counties_data = [
  {
    name: "Baringo",
    capital: "Kabarnet",
    county_code: 30,
    sub_counties: [
      { name: "Baringo Central", sub_county_code: 159 },
      { name: "Baringo North", sub_county_code: 158 },
      { name: "Baringo South", sub_county_code: 160 },
      { name: "Eldama Ravine", sub_county_code: 162 },
      { name: "Mogotio", sub_county_code: 161 },
      { name: "Tiaty", sub_county_code: 157 }
    ]
  },
  {
    name: "Bomet",
    capital: "Bomet",
    county_code: 36,
    sub_counties: [
      { name: "Bomet Central", sub_county_code: 197 },
      { name: "Bomet East", sub_county_code: 196 },
      { name: "Chepalungu", sub_county_code: 195 },
      { name: "Konoin", sub_county_code: 198 },
      { name: "Sotik", sub_county_code: 194 }
    ]
  },
  {
    name: "Bungoma",
    capital: "Bungoma",
    county_code: 39,
    sub_counties: [
      { name: "Bumula", sub_county_code: 219 },
      { name: "Kabuchai", sub_county_code: 218 },
      { name: "Kanduyi", sub_county_code: 220 },
      { name: "Kimilil", sub_county_code: 223 },
      { name: "Mt Elgon", sub_county_code: 216 },
      { name: "Sirisia", sub_county_code: 217 },
      { name: "Tongaren", sub_county_code: 224 },
      { name: "Webuye East", sub_county_code: 221 },
      { name: "Webuye West", sub_county_code: 222 }
    ]
  },
  {
    name: "Busia",
    capital: "Busia",
    county_code: 40,
    sub_counties: [
      { name: "Budalangi", sub_county_code: 231 },
      { name: "Butula", sub_county_code: 229 },
      { name: "Funyula", sub_county_code: 230 },
      { name: "Nambale", sub_county_code: 227 },
      { name: "Teso North", sub_county_code: 225 },
      { name: "Teso South", sub_county_code: 226 }
    ]
  },
  {
    name: "Elgeyo-Marakwet",
    capital: "Iten",
    county_code: 28,
    sub_counties: [
      { name: "Keiyo North", sub_county_code: 149 },
      { name: "Keiyo South", sub_county_code: 150 },
      { name: "Marakwet East", sub_county_code: 147 },
      { name: "Marakwet West", sub_county_code: 148 }
    ]
  },
  {
    name: "Embu",
    capital: "Embu",
    county_code: 14,
    sub_counties: [
      { name: "Manyatta", sub_county_code: 63 },
      { name: "Mbeere North", sub_county_code: 66 },
      { name: "Mbeere South", sub_county_code: 65 },
      { name: "Runyenjes", sub_county_code: 64 }
    ]
  },
  {
    name: "Garissa",
    capital: "Garissa",
    county_code: 7,
    sub_counties: [
      { name: "Balambala", sub_county_code: 28 },
      { name: "Daadab", sub_county_code: 30 },
      { name: "Fafi", sub_county_code: 31 },
      { name: "Garissa Township", sub_county_code: 27 },
      { name: "Ijara", sub_county_code: 32 },
      { name: "Lagdera", sub_county_code: 29 }
    ]
  },
  {
    name: "Homa Bay",
    capital: "Homa Bay",
    county_code: 43,
    sub_counties: [
      { name: "Homabay Township", sub_county_code: 249 },
      { name: "Kabondo Kapisul", sub_county_code: 246 },
      { name: "Karachuonyo", sub_county_code: 247 },
      { name: "Kasipul", sub_county_code: 245 },
      { name: "Mbita", sub_county_code: 251 },
      { name: "Ndhiwa", sub_county_code: 250 },
      { name: "Rangwe", sub_county_code: 248 },
      { name: "Suba", sub_county_code: 252 }
    ]
  },
  {
    name: "Isiolo",
    capital: "Isiolo",
    county_code: 11,
    sub_counties: [
      { name: "Isiolo North", sub_county_code: 49 },
      { name: "Isiolo South", sub_county_code: 50 }
    ]
  },
  {
    name: "Kajiado",
    capital: "Kajiado",
    county_code: 34,
    sub_counties: [
      { name: "Kajiado Central", sub_county_code: 184 },
      { name: "Kajiado East", sub_county_code: 185 },
      { name: "Kajiado North", sub_county_code: 183 },
      { name: "Kajiado South", sub_county_code: 187 },
      { name: "Kajiado West", sub_county_code: 186 }
    ]
  },
  {
    name: "Kakamega",
    capital: "Kakamega",
    county_code: 37,
    sub_counties: [
      { name: "Butere", sub_county_code: 207 },
      { name: "Ikolomani", sub_county_code: 210 },
      { name: "Khwisero", sub_county_code: 208 },
      { name: "Likuyani", sub_county_code: 200 },
      { name: "Lugari", sub_county_code: 201 },
      { name: "Lurambi", sub_county_code: 202 },
      { name: "Malava", sub_county_code: 201 },
      { name: "Matungu", sub_county_code: 3712 },
      { name: "Mumias East", sub_county_code: 205 },
      { name: "Mumias West", sub_county_code: 204 },
      { name: "Navakholo", sub_county_code: 203 },
      { name: "Shinyalu", sub_county_code: 209 }
    ]
  },
  {
    name: "Kericho",
    capital: "Kericho",
    county_code: 35,
    sub_counties: [
      { name: "Ainamoi", sub_county_code: 190 },
      { name: "Belgut", sub_county_code: 192 },
      { name: "Bureti", sub_county_code: 191 },
      { name: "Kipkelion East", sub_county_code: 188 },
      { name: "Kipkelion West", sub_county_code: 189 },
      { name: "Soin Sigowet", sub_county_code: 193 }
    ]
  },
  {
    name: "Kiambu",
    capital: "Kiambu",
    county_code: 22,
    sub_counties: [
      { name: "Gatundu North", sub_county_code: 112 },
      { name: "Gatundu South", sub_county_code: 111 },
      { name: "Githunguri", sub_county_code: 116 },
      { name: "Juja", sub_county_code: 113 },
      { name: "Kabete", sub_county_code: 119 },
      { name: "Kiambaa", sub_county_code: 118 },
      { name: "Kiambu", sub_county_code: 117 },
      { name: "Kikuyu", sub_county_code: 120 },
      { name: "Lari", sub_county_code: 122 },
      { name: "Limuru", sub_county_code: 121 },
      { name: "Ruiru", sub_county_code: 115 },
      { name: "Thika Town", sub_county_code: 114 }
    ]
  },
  {
    name: "Kilifi",
    capital: "Kilifi",
    county_code: 3,
    sub_counties: [
      { name: "Ganze", sub_county_code: 15 },
      { name: "Kaloleni", sub_county_code: 13 },
      { name: "Kilifi North", sub_county_code: 11 },
      { name: "Kilifi South", sub_county_code: 12 },
      { name: "Magarini", sub_county_code: 17 },
      { name: "Malindi", sub_county_code: 16 },
      { name: "Rabai", sub_county_code: 14 }
    ]
  },
  {
    name: "Kirinyaga",
    capital: "Kerugoya/Kutus",
    county_code: 20,
    sub_counties: [
      { name: "Gichugu", sub_county_code: 101 },
      { name: "Kirinyaga Central", sub_county_code: 103 },
      { name: "Mwea", sub_county_code: 100 },
      { name: "Ndia", sub_county_code: 102 }
    ]
  },
  {
    name: "Kisii",
    capital: "Kisii",
    county_code: 45,
    sub_counties: [
      { name: "Bobasi", sub_county_code: 264 },
      { name: "Bonchari", sub_county_code: 261 },
      { name: "Bomachoge Borabu", sub_county_code: 263 },
      { name: "Bomachoge Chache", sub_county_code: 265 },
      { name: "Kitutu Chache North", sub_county_code: 268 },
      { name: "Kitutu Chache South", sub_county_code: 269 },
      { name: "Nyaribari Chache", sub_county_code: 267 },
      { name: "Nyaribari Masaba", sub_county_code: 266 },
      { name: "South Mugirango", sub_county_code: 262 }
    ]
  },
  {
    name: "Kisumu",
    capital: "Kisumu",
    county_code: 42,
    sub_counties: [
      { name: "Kisumu Central", sub_county_code: 240 },
      { name: "Kisumu East", sub_county_code: 238 },
      { name: "Kisumu West", sub_county_code: 239 },
      { name: "Muhoroni", sub_county_code: 243 },
      { name: "Nyakach", sub_county_code: 244 },
      { name: "Nyando", sub_county_code: 242 },
      { name: "Seme", sub_county_code: 241 }
    ]
  },
  {
    name: "Kitui",
    capital: "Kitui",
    county_code: 15,
    sub_counties: [
      { name: "Kitui Central", sub_county_code: 72 },
      { name: "Kitui East", sub_county_code: 73 },
      { name: "Kitui Rural", sub_county_code: 71 },
      { name: "Kitui South", sub_county_code: 74 },
      { name: "Kitui West", sub_county_code: 70 },
      { name: "Mwingi Central", sub_county_code: 69 },
      { name: "Mwingi North", sub_county_code: 67 },
      { name: "Mwingi West", sub_county_code: 68 }
    ]
  },
  {
    name: "Kwale",
    capital: "Kwale",
    county_code: 2,
    sub_counties: [
      { name: "Kinango", sub_county_code: 10 },
      { name: "Lungalunga", sub_county_code: 8 },
      { name: "Msambweni", sub_county_code: 7 },
      { name: "Matuga", sub_county_code: 9 }
    ]
  },
  {
    name: "Laikipia",
    capital: "Rumuruti",
    county_code: 31,
    sub_counties: [
      { name: "Laikipia East", sub_county_code: 164 },
      { name: "Laikipia North", sub_county_code: 165 },
      { name: "Laikipia West", sub_county_code: 163 }
    ]
  },
  {
    name: "Lamu",
    capital: "Lamu",
    county_code: 5,
    sub_counties: [
      { name: "Lamu East", sub_county_code: 21 },
      { name: "Lamu West", sub_county_code: 22 }
    ]
  },
  {
    name: "Machakos",
    capital: "Machakos",
    county_code: 16,
    sub_counties: [
      { name: "Kangundo", sub_county_code: 77 },
      { name: "Kathiani", sub_county_code: 79 },
      { name: "Machakos Town", sub_county_code: 81 },
      { name: "Masinga", sub_county_code: 75 },
      { name: "Matungulu", sub_county_code: 78 },
      { name: "Mavoko", sub_county_code: 80 },
      { name: "Mwala", sub_county_code: 82 },
      { name: "Yatta", sub_county_code: 76 }
    ]
  },
  {
    name: "Makueni",
    capital: "Wote",
    county_code: 17,
    sub_counties: [
      { name: "Kaiti", sub_county_code: 85 },
      { name: "Kibwezi East", sub_county_code: 88 },
      { name: "Kibwezi West", sub_county_code: 87 },
      { name: "Kilome", sub_county_code: 84 },
      { name: "Makueni", sub_county_code: 86 },
      { name: "Mbooni", sub_county_code: 83 }
    ]
  },
  {
    name: "Mandera",
    capital: "Mandera",
    county_code: 9,
    sub_counties: [
      { name: "Banissa", sub_county_code: 40 },
      { name: "Lafey", sub_county_code: 44 },
      { name: "Mandera East", sub_county_code: 43 },
      { name: "Mandera North", sub_county_code: 41 },
      { name: "Mandera South", sub_county_code: 42 },
      { name: "Mandera West", sub_county_code: 39 }
    ]
  },
  {
    name: "Marsabit",
    capital: "Marsabit",
    county_code: 10,
    sub_counties: [
      { name: "Laisamis", sub_county_code: 48 },
      { name: "Moyale", sub_county_code: 45 },
      { name: "North Horr", sub_county_code: 46 },
      { name: "Saku", sub_county_code: 47 }
    ]
  },
  {
    name: "Meru",
    capital: "Meru",
    county_code: 12,
    sub_counties: [
      { name: "Buuri", sub_county_code: 57 },
      { name: "Igembe Central", sub_county_code: 52 },
      { name: "Igembe North", sub_county_code: 53 },
      { name: "Igembe South", sub_county_code: 51 },
      { name: "Imenti North", sub_county_code: 56 },
      { name: "Imenti South", sub_county_code: 59 },
      { name: "Tigania East", sub_county_code: 55 },
      { name: "Tigania West", sub_county_code: 54 }
    ]
  },
  {
    name: "Migori",
    capital: "Migori",
    county_code: 44,
    sub_counties: [
      { name: "Awendo", sub_county_code: 254 },
      { name: "Kuria East", sub_county_code: 260 },
      { name: "Kuria West", sub_county_code: 259 },
      { name: "Nyatike", sub_county_code: 258 },
      { name: "Rongo", sub_county_code: 253 },
      { name: "Suna East", sub_county_code: 255 },
      { name: "Suna West", sub_county_code: 256 },
      { name: "Uriri", sub_county_code: 257 }
    ]
  },
  {
    name: "Mombasa",
    capital: "Mombasa City",
    county_code: 1,
    sub_counties: [
      { name: "Changamwe", sub_county_code: 1 },
      { name: "Jomvu", sub_county_code: 2 },
      { name: "Kisauni", sub_county_code: 3 },
      { name: "Likoni", sub_county_code: 5 },
      { name: "Mvita", sub_county_code: 6 },
      { name: "Nyali", sub_county_code: 4 }
    ]
  },
  {
    name: "Murang'a",
    capital: "Murang'a",
    county_code: 21,
    sub_counties: [
      { name: "Gatanga", sub_county_code: 110 },
      { name: "Kandara", sub_county_code: 109 },
      { name: "Kangema", sub_county_code: 104 },
      { name: "Kigumo", sub_county_code: 107 },
      { name: "Kiharu", sub_county_code: 106 },
      { name: "Maragwa", sub_county_code: 108 },
      { name: "Mathioya", sub_county_code: 105 }
    ]
  },
  {
    name: "Nairobi",
    capital: "Nairobi City",
    county_code: 47,
    sub_counties: [
      { name: "Dagoretti North", sub_county_code: 275 },
      { name: "Dagoretti South", sub_county_code: 276 },
      { name: "Embakasi Central", sub_county_code: 284 },
      { name: "Embakasi East", sub_county_code: 285 },
      { name: "Embakasi North", sub_county_code: 283 },
      { name: "Embakasi South", sub_county_code: 282 },
      { name: "Embakasi West", sub_county_code: 286 },
      { name: "Kamukunji", sub_county_code: 288 },
      { name: "Kasarani", sub_county_code: 280 },
      { name: "Kibra", sub_county_code: 278 },
      { name: "Lang'ata", sub_county_code: 277 },
      { name: "Makadara", sub_county_code: 287 },
      { name: "Mathare", sub_county_code: 290 },
      { name: "Roysambu", sub_county_code: 279 },
      { name: "Ruaraka", sub_county_code: 281 },
      { name: "Starehe", sub_county_code: 289 },
      { name: "Westlands", sub_county_code: 274 }
    ]
  },
  {
    name: "Nakuru",
    capital: "Nakuru",
    county_code: 32,
    sub_counties: [
      { name: "Bahati", sub_county_code: 174 },
      { name: "Gilgil", sub_county_code: 169 },
      { name: "Kuresoi North", sub_county_code: 171 },
      { name: "Kuresoi South", sub_county_code: 170 },
      { name: "Molo", sub_county_code: 166 },
      { name: "Naivasha", sub_county_code: 168 },
      { name: "Nakuru Town East", sub_county_code: 176 },
      { name: "Nakuru Town West", sub_county_code: 175 },
      { name: "Njoro", sub_county_code: 167 },
      { name: "Rongai", sub_county_code: 173 },
      { name: "Subukia", sub_county_code: 172 }
    ]
  },
  {
    name: "Nandi",
    capital: "Kapsabet",
    county_code: 29,
    sub_counties: [
      { name: "Aldai", sub_county_code: 152 },
      { name: "Chesumei", sub_county_code: 154 },
      { name: "Emgwen", sub_county_code: 155 },
      { name: "Mosop", sub_county_code: 156 },
      { name: "Nandi Hills", sub_county_code: 153 },
      { name: "Tindiret", sub_county_code: 151 }
    ]
  },
  {
    name: "Narok",
    capital: "Narok",
    county_code: 33,
    sub_counties: [
      { name: "Emurua Dikirr", sub_county_code: 178 },
      { name: "Kilgoris", sub_county_code: 177 },
      { name: "Narok East", sub_county_code: 180 },
      { name: "Narok North", sub_county_code: 179 },
      { name: "Narok South", sub_county_code: 181 },
      { name: "Narok West", sub_county_code: 182 }
    ]
  },
  {
    name: "Nyamira",
    capital: "Nyamira",
    county_code: 46,
    sub_counties: [
      { name: "Borabu", sub_county_code: 273 },
      { name: "Kitutu Masaba", sub_county_code: 270 },
      { name: "Mugirango North", sub_county_code: 272 },
      { name: "Mugirango West", sub_county_code: 271 }
    ]
  },
  {
    name: "Nyandarua",
    capital: "Ol Kalou",
    county_code: 18,
    sub_counties: [
      { name: "Kinangop", sub_county_code: 89 },
      { name: "Kipipiri", sub_county_code: 90 },
      { name: "Ndaragwa", sub_county_code: 93 },
      { name: "Ol Jorok", sub_county_code: 92 },
      { name: "Ol Kalou", sub_county_code: 91 }
    ]
  },
  {
    name: "Nyeri",
    capital: "Nyeri",
    county_code: 19,
    sub_counties: [
      { name: "Kieni", sub_county_code: 95 },
      { name: "Mathira", sub_county_code: 96 },
      { name: "Mukurweini", sub_county_code: 98 },
      { name: "Nyeri Town", sub_county_code: 99 },
      { name: "Othaya", sub_county_code: 97 },
      { name: "Tetu", sub_county_code: 94 }
    ]
  },
  {
    name: "Samburu",
    capital: "Maralal",
    county_code: 25,
    sub_counties: [
      { name: "Samburu East", sub_county_code: 135 },
      { name: "Samburu North", sub_county_code: 134 },
      { name: "Samburu West", sub_county_code: 133 }
    ]
  },
  {
    name: "Siaya",
    capital: "Siaya",
    county_code: 41,
    sub_counties: [
      { name: "Alego Usonga", sub_county_code: 234 },
      { name: "Bondo", sub_county_code: 236 },
      { name: "Gem", sub_county_code: 235 },
      { name: "Rarieda", sub_county_code: 237 },
      { name: "Ugenya", sub_county_code: 232 },
      { name: "Ugunja", sub_county_code: 233 }
    ]
  },
  {
    name: "Taita-Taveta",
    capital: "Voi",
    county_code: 6,
    sub_counties: [
      { name: "Mwatate", sub_county_code: 25 },
      { name: "Taveta", sub_county_code: 23 },
      { name: "Voi", sub_county_code: 26 },
      { name: "Wundanyi", sub_county_code: 26 } # Note: Duplicate sub_county_code
    ]
  },
  {
    name: "Tana River",
    capital: "Hola",
    county_code: 4,
    sub_counties: [
      { name: "Bura", sub_county_code: 20 },
      { name: "Galole", sub_county_code: 19 },
      { name: "Garsen", sub_county_code: 18 }
    ]
  },
  {
    name: "Tharaka-Nithi",
    capital: "Chuka",
    county_code: 13,
    sub_counties: [
      { name: "Chuka/Igambang'ombe", sub_county_code: 61 },
      { name: "Maara", sub_county_code: 60 },
      { name: "Tharaka", sub_county_code: 62 }
    ]
  },
  {
    name: "Trans-Nzoia",
    capital: "Kitale",
    county_code: 26,
    sub_counties: [
      { name: "Cherangany", sub_county_code: 140 },
      { name: "Endebess", sub_county_code: 137 },
      { name: "Kiminini", sub_county_code: 139 },
      { name: "Kwanza", sub_county_code: 136 },
      { name: "Saboti", sub_county_code: 138 }
    ]
  },
  {
    name: "Turkana",
    capital: "Lodwar",
    county_code: 23,
    sub_counties: [
      { name: "Loima", sub_county_code: 126 },
      { name: "Turkana Central", sub_county_code: 125 },
      { name: "Turkana East", sub_county_code: 128 },
      { name: "Turkana North", sub_county_code: 123 },
      { name: "Turkana South", sub_county_code: 127 },
      { name: "Turkana West", sub_county_code: 124 }
    ]
  },
  {
    name: "Uasin Gishu",
    capital: "Eldoret",
    county_code: 27,
    sub_counties: [
      { name: "Ainabkoi", sub_county_code: 144 },
      { name: "Kapseret", sub_county_code: 145 },
      { name: "Kesses", sub_county_code: 146 },
      { name: "Moiben", sub_county_code: 143 },
      { name: "Soy", sub_county_code: 141 },
      { name: "Turbo", sub_county_code: 142 }
    ]
  },
  {
    name: "Vihiga",
    capital: "Vihiga",
    county_code: 38,
    sub_counties: [
      { name: "Emuhaya", sub_county_code: 215 },
      { name: "Hamisi", sub_county_code: 213 },
      { name: "Luanda", sub_county_code: 214 },
      { name: "Sabatia", sub_county_code: 212 },
      { name: "Vihiga", sub_county_code: 211 }
    ]
  },
  {
    name: "Wajir",
    capital: "Wajir",
    county_code: 8,
    sub_counties: [
      { name: "Eldas", sub_county_code: 37 },
      { name: "Tarbaj", sub_county_code: 35 },
      { name: "Wajir East", sub_county_code: 34 },
      { name: "Wajir North", sub_county_code: 33 },
      { name: "Wajir South", sub_county_code: 38 },
      { name: "Wajir West", sub_county_code: 36 }
    ]
  },
  {
    name: "West Pokot",
    capital: "Kapenguria",
    county_code: 24,
    sub_counties: [
      { name: "Kacheliba", sub_county_code: 131 },
      { name: "Kapenguria", sub_county_code: 129 },
      { name: "Pokot South", sub_county_code: 132 },
      { name: "Sigor", sub_county_code: 130 }
    ]
  }
]

counties_data.each do |county_data|
  county = County.find_or_create_by!(
    name: county_data[:name],
    county_code: county_data[:county_code]
  ) do |c|
    c.capital = county_data[:capital]
  end

  county_data[:sub_counties].each do |sub_county_data|
    SubCounty.find_or_create_by!(
      name: sub_county_data[:name],
      sub_county_code: sub_county_data[:sub_county_code],
      county: county
    )
  end
end

puts "Counties and Sub-Counties have been seeded successfully!"



# Set to keep track of used phone numbers
used_phone_numbers = Set.new

# Method to generate a unique phone number
def generate_custom_phone_number(used_phone_numbers)
  loop do
    phone_number = "07#{Faker::Number.number(digits: 8)}"
    return phone_number unless used_phone_numbers.include?(phone_number)
  end
end

# Method to generate a valid Kenyan motorbike license plate
def generate_motorbike_license_plate
  letters = ('A'..'Z').to_a - %w[I O]  # Exclude "I" and "O"
  "#{['KM', letters.sample, letters.sample].join}-#{rand(1..999).to_s.rjust(3, '0')}#{letters.sample}"
end

# Seed Vehicle Types if not already added
vehicle_types = ["Motorbike", "Tuk-Tuk", "Car", "Pick-Up", "Van"]

vehicle_types.each do |type|
  VehicleType.find_or_create_by(name: type)
end

# Ensure counties and sub-counties exist
if County.any?
  counties = County.includes(:sub_counties).all
  nairobi = County.includes(:sub_counties).find_by(name: 'Nairobi') # Get Nairobi County
  unless nairobi
    puts "Nairobi County not found! Ensure it is present in the database."
    exit
  end
else
  puts "No counties found. Ensure migration and seeding for counties is completed first."
  exit
end

# Helper function to assign county and sub-county
def assign_county_and_sub_county(counties, nairobi)
  if rand < 0.75 # 75% probability
    county = nairobi
  else
    county = counties.reject { |c| c.id == nairobi.id }.sample # Pick a random county other than Nairobi
  end
  sub_county = county.sub_counties.sample if county.sub_counties.any?
  [county.id, sub_county&.id]
end

# Seed 50 Riders (75% from Nairobi)
50.times do
  county_id, sub_county_id = assign_county_and_sub_county(counties, nairobi)

  Rider.find_or_create_by(email: nil) do |rider|
    full_name = Faker::Name.name
    username = full_name.downcase.gsub(/\s+/, "")
    email = "#{username}@example.com"

    rider.full_name = full_name
    rider.phone_number = generate_custom_phone_number(used_phone_numbers)
    used_phone_numbers.add(rider.phone_number)
    rider.age_group_id = AgeGroup.pluck(:id).sample
    rider.email = email
    rider.id_number = Faker::Number.number(digits: 8).to_s
    rider.driving_license = Faker::DrivingLicence.british_driving_licence
    rider.vehicle_type = "Motorbike"
    rider.license_plate = generate_motorbike_license_plate
    rider.password = 'rider@123'
    rider.physical_address = Faker::Address.full_address
    rider.gender = ['Male', 'Female'].sample

    # Assign county and sub-county
    rider.county_id = county_id
    rider.sub_county_id = sub_county_id
  end
end

# Seed 100 Buyers (75% from Nairobi)
100.times do
  county_id, sub_county_id = assign_county_and_sub_county(counties, nairobi)

  Buyer.find_or_create_by(email: nil) do |buyer|
    fullname = Faker::Name.name
    username = fullname.downcase.gsub(/\s+/, "")
    email = "#{username}@example.com"

    buyer.fullname = fullname
    buyer.username = username
    buyer.email = email
    buyer.phone_number = generate_custom_phone_number(used_phone_numbers)
    used_phone_numbers.add(buyer.phone_number)
    buyer.location = Faker::Address.full_address
    buyer.password = 'password'

    # Assign county and sub-county
    buyer.county_id = county_id
    buyer.sub_county_id = sub_county_id

    # Additional fields
    # Replace birthdate with random age_group_id
    buyer.age_group_id = AgeGroup.pluck(:id).sample
    buyer.zipcode = Faker::Address.zip_code
    buyer.city = Faker::Address.city
    buyer.gender = ['Male', 'Female'].sample
    buyer.profile_picture = Faker::Avatar.image

    # Assign new attributes
    buyer.income_id = Income.all.sample.id
    buyer.employment_id = Employment.all.sample.id
    buyer.education_id = Education.all.sample.id
    buyer.sector_id = Sector.all.sample.id
  end
end

# Seed 50 Sellers (50% from Nairobi)
tier_durations = [1, 3, 6, 12] # Define valid durations in months

50.times do
  county_id, sub_county_id = assign_county_and_sub_county(counties, nairobi)

  fullname = Faker::Name.name
  username = fullname.downcase.gsub(/\s+/, "")
  email = "#{username}@example.com"

  seller = Seller.find_or_create_by(email: email) do |seller|
    seller.fullname = fullname
    seller.username = username
    seller.email = email
    seller.phone_number = generate_custom_phone_number(used_phone_numbers)
    used_phone_numbers.add(seller.phone_number)
    seller.enterprise_name = "#{Faker::Company.name} #{Faker::Company.suffix}"
    seller.description = Faker::Company.bs
    seller.location = Faker::Address.full_address
    seller.password = 'password'
    seller.business_registration_number = "BN/#{Faker::Number.number(digits: 4)}/#{Faker::Number.number(digits: 6)}"

    # Assign county and sub-county
    seller.county_id = county_id
    seller.sub_county_id = sub_county_id

    # Assign random category if available
    if Category.any?
      seller.category_ids = [Category.all.sample.id]
    else
      puts "No categories found for seller #{email}. Skipping seller."
      next
    end

    seller.age_group_id = AgeGroup.pluck(:id).sample
    seller.zipcode = Faker::Address.zip_code
    seller.city = Faker::Address.city
    seller.gender = ['Male', 'Female'].sample
    seller.profile_picture = Faker::Avatar.image
  end

  if seller.valid?
    puts "Seller created: #{seller.email} (County ID: #{county_id}, Sub-County ID: #{sub_county_id})"
  else
    puts "Seller validation failed for: #{seller.email}, Errors: #{seller.errors.full_messages}"
  end

  # Seed seller tier data
  if SellerTier.exists?(seller_id: seller.id)
    puts "SellerTier already exists for Seller ID: #{seller.id}. Skipping."
  else
    # Ensure there are tiers available
    if Tier.any?
      tier = Tier.all.sample # Assign a random tier
      duration = tier_durations.sample # Assign a random duration

      created_at_time = Faker::Time.backward(days: 30) # Randomized creation date within the last 30 days
      updated_at_time = Faker::Time.between(from: created_at_time, to: Time.now) # Ensure updated_at is after or equal to created_at

      SellerTier.create!(
        seller_id: seller.id,
        tier_id: tier.id,
        duration_months: duration,
        created_at: created_at_time,
        updated_at: updated_at_time
      )
      puts "SellerTier created for Seller ID: #{seller.id}, Tier ID: #{tier.id}, Duration: #{duration} months"
    else
      puts "No tiers found for seller #{seller.email}. Skipping tier assignment."
    end
  end
end
puts "Riders, Buyers, and Sellers have been seeded successfully!"

puts "Starts seeding the ads of the categories..."


category_ads = {
  'Filtration' => [
    { title: 'Water Filter', description: 'High-quality water filter for home use', media: ['https://m.media-amazon.com/images/I/71s7yQg7tjL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/716R+NXyn-L._AC_SX679_.jpg'] },
    { title: 'Air Purifier Filter', description: 'Filter for air purifiers', media: ['https://m.media-amazon.com/images/I/91lNyEeYIML.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/41vu1+gWIVL._AC_US100_.jpg'] },
    { title: 'HEPA Filter', description: 'High-efficiency particulate air filter for air purification', media: ['https://m.media-amazon.com/images/I/71wxFcsryqL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/71f-s8DHmQL._AC_SX679_.jpg'] },
    { title: 'Carbon Filter', description: 'Activated carbon filter for water and air filtration', media: ['https://m.media-amazon.com/images/I/81UxvvXfVxL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/51LAr1u0SGL._AC_US100_.jpg'] },
    { title: 'Reverse Osmosis Membrane', description: 'RO membrane for advanced water filtration', media: ['https://m.media-amazon.com/images/I/61hTq1GSb8L._SX522_.jpg', 'https://m.media-amazon.com/images/I/61VtjUpXuzS._AC_SX679_.jpg'] },
    { title: 'UV Water Filter', description: 'UV filter for sterilizing water', media: ['https://m.media-amazon.com/images/I/41EVsmhOXCL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/718ENZeONPL._SX522_.jpg'] },
    { title: 'Furnace Filter', description: 'Furnace filter for HVAC systems', media: ['https://m.media-amazon.com/images/I/81C1DwIdYYL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61WAUuZqasL._AC_SX679_.jpg'] },
    { title: 'Inline Water Filter', description: 'Inline filter for direct water filtration', media: ['https://m.media-amazon.com/images/I/71aCPQcwOVL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71-f3iKzEnL._AC_SX679_.jpg'] },
    { title: 'Pre-Filter', description: 'Pre-filter for removing larger particles from swimming pools', media: ['https://m.media-amazon.com/images/I/71+m3wn1HiL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/61Yrw-7We8L._AC_SX679_.jpg'] },
    { title: 'Sediment Filter', description: 'Sediment filter for removing dirt and rust', media: ['https://m.media-amazon.com/images/I/41sNDtAYu0L._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81v+xqbUiEL._SX522_.jpg'] },
    { title: 'Water Softener Filter', description: 'Filter for water softeners', media: ['https://m.media-amazon.com/images/I/31wyDXR3vWL._SX342_SY445_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61haYFmTEoL._SX522_.jpg'] },
    { title: 'KDF Filter', description: 'Kinetic degradation fluxion filter for water treatment', media: ['https://m.media-amazon.com/images/I/810vU+Ih0EL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/71vRuQ7HGbL._AC_SX679_.jpg'] },
    { title: 'Air Purifier HEPA Filter', description: 'HEPA filter for air purifiers', media: ['https://m.media-amazon.com/images/I/71+OwDDGetL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/614mMuQUZ0L._AC_SY879_.jpg'] },
    { title: 'Odor Filter', description: 'Filter for removing odors from air', media: ['https://m.media-amazon.com/images/I/81vGvmZOEeL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81z1mRaP7JL._AC_SX679_.jpg'] },
    { title: 'Bacteria Filter', description: 'Filter for removing bacteria from water', media: ['https://m.media-amazon.com/images/I/71Bx1wF2izL._SX522_.jpg', 'https://m.media-amazon.com/images/I/61GC73Ab95L._SX522_.jpg'] },
    { title: 'Chlorine Filter', description: 'Filter for removing chlorine from water', media: ['https://m.media-amazon.com/images/I/7142R+1VUaL._AC_SX679_PIbundle-2,TopRight,0,0_SH20_.jpg', 'https://m.media-amazon.com/images/I/819lG1tbhUL._AC_SX679_.jpg'] },
    { title: 'Chemical Filter', description: 'Filter for removing chemicals from water', media: ['https://m.media-amazon.com/images/I/61tXgp2RNxL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61dsE4gjOCL._AC_SX679_.jpg'] },
    { title: 'Multi-Stage Water Filter', description: 'Multi-stage filter for comprehensive water purification', media: ['https://m.media-amazon.com/images/I/91w2Yr9CGlL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/71uWouhuLAL._AC_SX679_.jpg'] },
    { title: 'Home Water Filter System', description: 'Complete water filter system for home use', media: ['https://m.media-amazon.com/images/I/71H4oBq+mrL._SX522_.jpg', 'https://m.media-amazon.com/images/I/71DT8WYFszL._SX522_.jpg'] },
    { title: 'Commercial Water Filter', description: 'Water filter system for commercial use', media: ['https://m.media-amazon.com/images/I/41oMgbWNr3L._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61KDR6vSnIL._SX522_.jpg'] },
    { title: 'Pool Filter', description: 'Filter for swimming pool water', media: ['https://m.media-amazon.com/images/I/816-kLrsA5L._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/71kNgbmw53L._AC_SX679_.jpg'] },
    { title: 'Aquarium Filter', description: 'Filter for aquarium water', media: ['https://m.media-amazon.com/images/I/91amRCg3P0L._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/71vF-P1IgFL._AC_SX679_.jpg'] },
    { title: 'Coffee Maker Water Filter', description: 'Filter for coffee makers', media: ['https://m.media-amazon.com/images/I/71NXo5KG+1L._AC_SX300_SY300_.jpg', 'https://m.media-amazon.com/images/I/71hDThr4LjL._AC_SX679_.jpg'] },
    { title: 'Refrigerator Water Filter', description: 'Filter for refrigerator water dispensers', media: ['https://m.media-amazon.com/images/I/61loAhZhVGL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61MKfXQ9JvL._AC_SX679_.jpg'] },
    { title: 'Under Sink Water Filter', description: 'Under sink filter for clean drinking water', media: ['https://m.media-amazon.com/images/I/610B6uiS-8L._SX522_.jpg', 'https://m.media-amazon.com/images/I/61hSjoxfr7L._SX522_.jpg'] },
    { title: 'Shower Filter', description: 'Filter for removing impurities from shower water', media: ['https://m.media-amazon.com/images/I/71KrTpNAQqL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81+GwDjeV5L._AC_SX679_.jpg'] },
    { title: 'Whole House Water Filter', description: 'Filter system for treating water for the entire house', media: ['https://m.media-amazon.com/images/I/511rtOGGL-L._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/815qfOVzErL._SX522_.jpg'] },
    { title: 'Drinking Water Filter', description: 'Filter designed specifically for drinking water', media: ['https://m.media-amazon.com/images/I/51a5ku-MyBL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81Zi4-gqDRL._SX522_.jpg'] },
    { title: 'Ice Maker Water Filter', description: 'Filter for ice maker water', media: ['https://m.media-amazon.com/images/I/6116DU4fsuL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/71jya9t+Z8L._AC_SX679_.jpg'] },
    { title: 'Whole House Carbon Filter', description: 'Carbon filter for whole house water filtration', media: ['https://m.media-amazon.com/images/I/81BQ0qk5EtL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/81z-yS6tnCL._AC_SX679_.jpg'] },
    { title: 'Whole House Sediment Filter', description: 'Sediment filter for whole house water filtration', media: ['https://m.media-amazon.com/images/I/613LFyIn9vL._AC_SY879_.jpg', 'https://m.media-amazon.com/images/I/71ULKqUy-cL._AC_SX679_.jpg'] },
    { title: 'Whole House UV Filter', description: 'UV filter for whole house water treatment', media: ['https://m.media-amazon.com/images/I/41aTZRXJPbL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71U3xLop+OL._SX522_.jpg'] },
    { title: 'Inline Carbon Filter', description: 'Inline carbon filter for water treatment', media: ['https://m.media-amazon.com/images/I/71i4KaaeKNL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/61cSKhB7oeL._AC_SX679_.jpg'] },
    { title: 'Inline Sediment Filter', description: 'Inline sediment filter for water treatment', media: ['https://m.media-amazon.com/images/I/51oPI2PmT-L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61u5aCr5A0L._AC_SX679_.jpg'] },
    { title: 'Inline HEPA Filter', description: 'Inline HEPA filter for air purification', media: ['https://m.media-amazon.com/images/I/51ZtOdXVjiL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/61eR-OdTnqL._AC_SX679_.jpg'] },
    { title: 'Air Purifier Carbon Filter', description: 'Carbon filter for air purifiers', media: ['https://m.media-amazon.com/images/I/8193AJLEfrL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81s2ZQUW3UL._AC_SX679_.jpg'] },
    { title: 'Central Air Filter', description: 'Filter for central air systems', media: ['https://m.media-amazon.com/images/I/81KgBUvC31L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81R78OPX5DL._AC_SX679_.jpg'] },
    { title: 'Washable Air Filter', description: 'Reusable and washable air filter', media: ['https://m.media-amazon.com/images/I/81xB6V3pLXL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/81gy11y5niL._AC_SX679_.jpg'] },
    { title: 'Disposable Air Filter', description: 'Disposable filter for air purification', media: ['https://m.media-amazon.com/images/I/81LDhVskQrL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/81I5kOL1wsL._AC_SX466_.jpg'] },
    { title: 'HEPA Air Filter', description: 'HEPA filter for air purification', media: ['https://m.media-amazon.com/images/I/710w2H0ip+L._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/81cRt146vWL._AC_SX679_.jpg'] },
    { title: 'Room Air Filter', description: 'Filter designed for room air purifiers', media: ['https://m.media-amazon.com/images/I/71PRcz7h9hL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71oKUxNPx7L._AC_SX679_.jpg'] },
    { title: 'Whole House Air Filter', description: 'Air filter system for the entire house', media: ['https://m.media-amazon.com/images/I/61LxiokMpML.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81mdcI+KkpL._AC_SX679_.jpg'] },
    { title: 'Air Purifier HEPA Filter Replacement', description: 'Replacement HEPA filter for air purifiers', media: ['https://m.media-amazon.com/images/I/81EsBlbtcQL.__AC_SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71c8DWrE37L._AC_SX679_.jpg'] },
    { title: 'Air Purifier Carbon Filter Replacement', description: 'Replacement carbon filter for air purifiers', media: ['https://m.media-amazon.com/images/I/71fwcGskbHL.__AC_SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81Js5EgpSSL._AC_SX679_.jpg'] },
    { title: 'Air Purifier Pre-Filter', description: 'Pre-filter for air purifiers', media: ['https://m.media-amazon.com/images/I/812+HK6ZcAL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/71nreo-aJYL._AC_SX679_.jpg'] },
    { title: 'Ozone Filter', description: 'Filter for removing ozone from air', media: ['https://m.media-amazon.com/images/I/71z8HSCIOuL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71jzbmSk8jL._AC_SX679_.jpg'] },
    { title: 'Electrostatic Filter', description: 'Electrostatic filter for air purification', media: ['https://m.media-amazon.com/images/I/71jS56bRsiL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/71CTQYQ08mL._AC_SX679_.jpg'] },
    { title: 'High Efficiency Air Filter', description: 'High-efficiency air filter for HVAC systems', media: ['https://m.media-amazon.com/images/I/81V4scrfXsL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/711M8WDEeWL._AC_SX679_.jpg'] },
    { title: 'Anti-Allergen Filter', description: 'Filter designed to reduce allergens in the air', media: ['https://m.media-amazon.com/images/I/81mSMJwbU0L.__AC_SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71cfK1bJqKL._AC_SX679_.jpg'] },
    { title: 'Anti-Microbial Filter', description: 'Filter with anti-microbial properties for air purification', media: ['https://m.media-amazon.com/images/I/81ji-x7WmxL.__AC_SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81jZUqYAx1L._AC_SX679_.jpg'] },
    { title: 'Dehumidifier Filter', description: 'Filter for dehumidifiers', media: ['https://m.media-amazon.com/images/I/61C0gFU9gmL.__AC_SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61ffXYuwzgL._AC_SX679_.jpg'] },
    { title: 'Ventilation Filter', description: 'Filter for ventilation systems', media: ['https://m.media-amazon.com/images/I/81xkbU3GmbL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81LowHF8DEL._AC_SX679_.jpg'] },
    { title: 'Car Air Filter', description: 'Air filter for vehicles', media: ['https://m.media-amazon.com/images/I/61nP1xuDxNL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/717Mc8xIFWL._AC_SX466_.jpg'] },
    { title: 'Cabin Air Filter', description: 'Filter for the cabin air of vehicles', media: ['https://m.media-amazon.com/images/I/81ENfg3++0L._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/61vHKvDhCUL._AC_SX466_.jpg'] },
    { title: 'Automotive HEPA Filter', description: 'HEPA filter for vehicles', media: ['https://m.media-amazon.com/images/I/81yevjQOTSL._AC_SX466_PIbundle-2,TopRight,0,0_SH20_.jpg', 'https://m.media-amazon.com/images/I/71uMyH5Op-L._AC_SX466_.jpg'] },
    { title: 'Automotive Carbon Filter', description: 'Carbon filter for vehicles', media: ['https://m.media-amazon.com/images/I/813hKFeeYLL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81IIJPASn2L._AC_SX466_.jpg'] },
    { title: 'Automotive Cabin Filter', description: 'Cabin filter for automotive air purification', media: ['https://m.media-amazon.com/images/I/71lG3mJkZuL.__AC_SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71OjBaD1eXL._AC_SX679_.jpg'] },
    { title: 'Engine Air Filter', description: 'Air filter for engines', media: ['https://m.media-amazon.com/images/I/71jtD8nC2ZL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81QJJPSfgmL._AC_SX466_.jpg'] },
    { title: 'Fuel Filter', description: 'Filter for removing impurities from fuel', media: ['https://m.media-amazon.com/images/I/81+5eH1yMWL._AC_SX300_SY300_.jpg', 'https://m.media-amazon.com/images/I/61BidIQ4XyL._AC_SX679_.jpg'] },
    { title: 'Transmission Filter', description: 'Filter for transmission fluid', media: ['https://m.media-amazon.com/images/I/61V9wse3tSL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/713YCjO1neL._AC_SX466_.jpg'] },
    { title: 'Oil Filter', description: 'Filter for engine oil', media: ['https://m.media-amazon.com/images/I/810QMRHYMeL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/710+h0PiJeL._AC_SX466_.jpg'] },
    { title: 'Automatic Transmission Filter', description: 'Filter for automatic transmission fluid', media: ['https://m.media-amazon.com/images/I/71+JB5P-GTL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/71PxwPBeJRL._AC_SX466_.jpg'] },
    { title: 'Hydraulic Filter', description: 'Filter for hydraulic systems', media: ['https://m.media-amazon.com/images/I/61keG3JD3lL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61pPhfJcGLL._AC_SX466_.jpg'] },
    { title: 'Industrial Air Filter', description: 'Air filter for industrial applications', media: ['https://m.media-amazon.com/images/I/71z40icsuBL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71UiK0-nhcL._AC_SX679_.jpg'] },
    { title: 'Industrial Water Filter', description: 'Water filter for industrial applications', media: ['https://m.media-amazon.com/images/I/71ISSMmAeXL._SX522_.jpg', 'https://m.media-amazon.com/images/I/513J99ZpPMS._SX522_.jpg'] },
    { title: 'Commercial Air Filter', description: 'Air filter for commercial settings', media: ['https://m.media-amazon.com/images/I/718Pl0t2T0L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71T6j34Ah6L._AC_SX679_.jpg'] },
    { title: 'Commercial Water Filter', description: 'Water filter for commercial settings', media: ['https://m.media-amazon.com/images/I/61moFP4n0JL.__AC_SX300_SY300_QL70_FMwebp_.jpgq', 'https://m.media-amazon.com/images/I/71NeBKwnfqL._AC_SX679_.jpg'] },
    { title: 'Large Capacity Air Filter', description: 'High-capacity air filter for large spaces', media: ['https://m.media-amazon.com/images/I/81iDUmUZYwL.__AC_SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71duLXLGCRL._AC_SX679_.jpg'] },
    { title: 'Large Capacity Water Filter', description: 'High-capacity water filter for large systems', media: ['https://m.media-amazon.com/images/I/61I9DU2qI0L._AC_UL320_.jpg', 'https://m.media-amazon.com/images/I/71-9+BQCiQL._AC_UL320_.jpg'] },
    { title: 'Portable Water Filter', description: 'Portable filter for on-the-go water purification', media: ['https://m.media-amazon.com/images/I/41mZSKRLpxL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/7119OlTwurL._SX425_.jpg'] },
    { title: 'Portable Air Filter', description: 'Portable air filter for mobile use', media: ['https://m.media-amazon.com/images/I/71ZMXXzNB6L._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/71vzqAKudnL.__AC_SX300_SY300_QL70_FMwebp_.jpg'] },
    { title: 'Desk Air Filter', description: 'Compact air filter for desk use', media: ['https://m.media-amazon.com/images/I/61IX7vlXEpL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81Lmplavp5L._AC_SX679_.jpg'] },
    { title: 'Air Filter Replacement', description: 'Replacement filter for air purifiers', media: ['https://m.media-amazon.com/images/I/61bE1Iw0MqL.__AC_SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71R0xEGFPvL._AC_SX679_.jpg'] },
    { title: 'Water Filter Cartridge', description: 'Cartridge for water filtration systems', media: ['https://m.media-amazon.com/images/I/71208H+OxeL._AC_SL1500_.jpg', 'https://m.media-amazon.com/images/I/71nB4mGgbLL._AC_SX679_.jpg'] },
    { title: 'Coffee Maker Water Filter Cartridge', description: 'Replacement cartridge for coffee maker water filters', media: ['https://m.media-amazon.com/images/I/81ls2BHX11S.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81wNRc7UYkL._AC_SX679_.jpg'] },
    { title: 'Refrigerator Water Filter Cartridge', description: 'Cartridge for refrigerator water filters', media: ['https://m.media-amazon.com/images/I/81HXxOWWhoL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/7176-s+CqsL._AC_SX679_.jpg'] },
    { title: 'Under Sink Filter Cartridge', description: 'Cartridge for under sink water filters', media: ['https://m.media-amazon.com/images/I/81rnj8pdAHL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81XCuq6rgUL._AC_SX679_.jpg'] },
    { title: 'Shower Filter Cartridge', description: 'Cartridge for shower water filters', media: ['https://m.media-amazon.com/images/I/71BIKNiQt9L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81eluyw2vSL._AC_SX679_.jpg'] },
    { title: 'Whole House Filter Cartridge', description: 'Cartridge for whole house water filters', media: ['https://m.media-amazon.com/images/I/81L2jVgvnxL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71EDlUTEs1L._AC_SX679_.jpg'] },
    { title: 'Pool Filter Cartridge', description: 'Cartridge for swimming pool filters', media: ['https://m.media-amazon.com/images/I/81bbsgxYnCL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81iSAjIfHGL._AC_SX679_.jpg'] },
    { title: 'Aquarium Filter Cartridge', description: 'Cartridge for aquarium filters', media: ['https://m.media-amazon.com/images/I/81Gl571Q1rL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81we3kCLlIL._AC_SX679_.jpg'] },
    { title: 'Industrial Water Filter Cartridge', description: 'Cartridge for industrial water filters', media: ['https://m.media-amazon.com/images/I/71XHS28aNZL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61L78X46gZL._AC_SX679_.jpg'] },
    { title: 'Commercial Water Filter Cartridge', description: 'Cartridge for commercial water filters', media: ['https://m.media-amazon.com/images/I/61uJ6jm0TbL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71iyxpNKSCL._AC_SX679_.jpg'] },
    { title: 'Sediment Filter Cartridge', description: 'Cartridge for sediment filters', media: ['https://m.media-amazon.com/images/I/81k7zPeY6FL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81hbTcEtXaL._AC_SX679_.jpg'] },
    { title: 'Carbon Block Filter', description: 'Carbon block filter for water purification', media: ['https://m.media-amazon.com/images/I/717R4PQZ9mL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/7149nOesF5L._AC_SX679_.jpg'] },
    { title: 'Activated Carbon Filter', description: 'Activated carbon filter for water and air', media: ['https://m.media-amazon.com/images/I/61NjIc7wccL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81sMtVyBGqL._AC_SX679_.jpg'] },
    { title: 'Ceramic Water Filter', description: 'Ceramic filter for water purification', media: ['https://m.media-amazon.com/images/I/611zBxMZgfL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/711ny4kCviL._AC_SX679_.jpg'] },
    { title: 'Titanium Water Filter', description: 'Titanium filter for advanced water filtration', media: ['https://m.media-amazon.com/images/I/41xScq-ueOL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71fOuUXPyRL._SX522_.jpg'] },
    { title: 'Stainless Steel Filter', description: 'Stainless steel filter for various applications', media: ['https://m.media-amazon.com/images/I/61IROdnY4HL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61RFSQfnJPL._AC_SX679_.jpg'] },
    { title: 'Stainless Steel Water Filter', description: 'Stainless steel filter for water purification', media: ['https://m.media-amazon.com/images/I/414h3Dr32ZL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81-J7N6-UjL._SX522_.jpg'] },
    { title: 'Sediment Removal Filter', description: 'Filter for removing sediment from water', media: ['https://m.media-amazon.com/images/I/517AJFV5ZUL._SX425_.jpg', 'https://m.media-amazon.com/images/I/81ias6INmcL._SX425_.jpg'] },
    { title: 'Pre-Carbon Filter', description: 'Pre-filter with carbon for water filtration', media: ['https://m.media-amazon.com/images/I/81mWJqCFkwL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/71WOyFQje5L._AC_SX679_.jpg'] },
    { title: 'Bio Filter', description: 'Bio filter for biological water treatment', media: ['https://m.media-amazon.com/images/I/719eO7I4pZL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/610qIAstNiL._AC_SX679_.jpg'] },
    { title: 'Iron Removal Filter', description: 'Filter for removing iron from water', media: ['https://m.media-amazon.com/images/I/21USo8skpdL.__AC_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/31wPbrfjwxL._AC_.jpg'] },
    { title: 'Manganese Removal Filter', description: 'Filter for removing manganese from water', media: ['https://m.media-amazon.com/images/I/419pfSdpHAL._SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71Cj3p9OkwL._SX679_.jpg'] },
    { title: 'Copper Removal Filter', description: 'Filter for removing copper from water', media: ['https://m.media-amazon.com/images/I/71D3IJ30AgL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71VjsAJYR1L._AC_SX679_.jpg'] },
    { title: 'Nitrate Removal Filter', description: 'Filter for removing nitrates from water', media: ['https://m.media-amazon.com/images/I/71j8gSGDz9L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/616HkVma00L._AC_SX679_.jpg'] },
    { title: 'Lead Removal Filter', description: 'Filter for removing lead from water', media: ['https://m.media-amazon.com/images/I/81w59SEvixL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/81pVrg-dMxL._AC_SX679_.jpg'] },
    { title: 'PFAS Removal Filter', description: 'Filter for removing PFAS from water', media: ['https://m.media-amazon.com/images/I/31O9ZBNTtyL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/51Pled1H2ML._SX522_.jpg'] },
    { title: 'Arsenic Removal Filter', description: 'Filter for removing arsenic from water', media: ['https://m.media-amazon.com/images/I/41zjyCc+OeL._SX342_SY445_.jpg', 'https://m.media-amazon.com/images/I/717nbGIH5EL._SX522_.jpg'] },
    { title: 'Radon Removal Filter', description: 'Filter for removing radon from water', media: ['https://m.media-amazon.com/images/I/31CBydh4XAL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61HYp32x7XL._SX522_.jpg'] },
    { title: 'Fluoride Removal Filter', description: 'Filter for removing fluoride from water', media: ['https://m.media-amazon.com/images/I/51U-CNVnn3L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61rvh811buL._AC_SX679_.jpg'] }
  ],



  ###
  


  ##

  'Hardware Tools' => [
    { title: 'Hammer', description: 'Durable hammer for various tasks', media: ['https://m.media-amazon.com/images/I/716uFZq0wAL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81jHRwcu-iL._AC_SX679_.jpg'] },
    { title: 'Screwdriver Set', description: 'Set of screwdrivers with various heads', media: ['https://m.media-amazon.com/images/I/71Jli9bYEnL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/712UpxUORcL._AC_SX679_.jpg'] },
    { title: 'Adjustable Wrench', description: 'Versatile wrench for multiple applications', media: ['https://m.media-amazon.com/images/I/71sP4V5wj4L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71+5EL03z9L._AC_SX679_.jpg'] },
    { title: 'Cordless Drill', description: 'High-performance cordless drill with battery', media: ['https://m.media-amazon.com/images/I/71A+etOyhvL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/71IQnMTWxaL._AC_SX679_.jpg'] },
    { title: 'Tape Measure', description: 'Reliable tape measure for accurate measurements', media: ['https://m.media-amazon.com/images/I/518quh3V+yL._SX342_SY445_.jpg', 'https://m.media-amazon.com/images/I/81y9zPytD0L._SX522_.jpg'] },
    { title: 'Utility Knife', description: 'Sharp utility knife for cutting tasks', media: ['https://m.media-amazon.com/images/I/81jVKbkaBLL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61UtU5HHtYL._AC_SX679_.jpg'] },
    { title: 'Pliers Set', description: 'Set of pliers for gripping and cutting', media: ['https://m.media-amazon.com/images/I/71Obh6ck4eL._SX522_.jpg', 'https://m.media-amazon.com/images/I/811gmjTmT7L._SX522_.jpg'] },
    { title: 'Level', description: 'Precision level for ensuring accurate alignment', media: ['https://m.media-amazon.com/images/I/71HOVTfoB4L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/717CqDHruDL._AC_SX679_.jpg'] },
    { title: 'Circular Saw', description: 'Powerful circular saw for cutting wood and other materials', media: ['https://m.media-amazon.com/images/I/81MvdZ4Y4WL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81PAM+qoPoL._AC_SX679_.jpg'] },
    { title: 'Chisel Set', description: 'Set of chisels for woodworking and carving', media: ['https://m.media-amazon.com/images/I/81lFKVfOjEL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71qXLwn5YoL._AC_SX679_.jpg'] },
    { title: 'Socket Wrench Set', description: 'Comprehensive socket wrench set for automotive work', media: ['https://m.media-amazon.com/images/I/81mI9Y+Q3XL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/81L282rWH6L._AC_SX679_.jpg'] },
    { title: 'Allen Wrench Set', description: 'Hex key set for assembling furniture and equipment', media: ['https://m.media-amazon.com/images/I/71yQBneZA3L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71XGcEufhOS._AC_SX679_.jpg'] },
    { title: 'Claw Hammer', description: 'Heavy-duty claw hammer for construction tasks', media: ['https://m.media-amazon.com/images/I/613yLITO21L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71yKenZDlzL._AC_SX679_.jpg'] },
    { title: 'Rubber Mallet', description: 'Soft rubber mallet for gentle striking', media: ['https://m.media-amazon.com/images/I/31TgPEqIv6L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/51sFQ1-DkZL._AC_SX679_.jpg'] },
    { title: 'Hacksaw', description: 'Adjustable hacksaw for cutting metal and plastic', media: ['https://m.media-amazon.com/images/I/61kka0uhdeL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71TQz3kX4cL._AC_SX679_.jpg'] },
    { title: 'Handsaw', description: 'Sharp handsaw for precise cutting of wood', media: ['https://m.media-amazon.com/images/I/61XIfJcQIuL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71eOWnKfG2L._AC_SX679_.jpg'] },
    { title: 'Jigsaw', description: 'Electric jigsaw for curved and intricate cuts', media: ['https://m.media-amazon.com/images/I/71fbAzlbkZL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/814L+FwzJYL._AC_SX679_.jpg'] },
    { title: 'Sledgehammer', description: 'Heavy sledgehammer for demolition work', media: ['https://m.media-amazon.com/images/I/71oD+cxcBZL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/71bcfFhJ2qL._AC_SX679_.jpg'] },
    { title: 'Pipe Wrench', description: 'Adjustable pipe wrench for plumbing tasks', media: ['https://m.media-amazon.com/images/I/71J7GQK-Z0S._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/61dUJ6357vS._AC_SX679_.jpg'] },
    { title: 'Needle-Nose Pliers', description: 'Long-nose pliers for reaching tight spaces', media: ['https://m.media-amazon.com/images/I/71EQquE38wL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/818lBmotnXL._AC_SX679_.jpg'] },
    { title: 'Vise Grip Pliers', description: 'Locking pliers with adjustable grip', media: ['https://m.media-amazon.com/images/I/81djRUffIgL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71AkMqCs0VL._AC_SX679_.jpg'] },
    { title: 'Crescent Wrench', description: 'Adjustable crescent wrench for various nuts and bolts', media: ['https://m.media-amazon.com/images/I/61f2DwuAxYL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61f1MqGwmBL._AC_SX679_.jpg'] },
    { title: 'Tin Snips', description: 'Sharp tin snips for cutting sheet metal', media: ['https://m.media-amazon.com/images/I/71vTvEFqtpL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/610TIjPJxcS.__AC_SX300_SY300_QL70_FMwebp_.jpg'] },
    { title: 'Wire Strippers', description: 'Precision wire strippers for electrical work', media: ['https://m.media-amazon.com/images/I/61OtPfu3CzL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71bqoqtZzHL._AC_SX679_.jpg'] },
    { title: 'Bolt Cutters', description: 'Heavy-duty bolt cutters for cutting metal rods and chains', media: ['https://m.media-amazon.com/images/I/71Vzq9bvtfL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71Se1duvlxL._AC_SX679_.jpg'] },
    { title: 'Staple Gun', description: 'Manual staple gun for fastening materials', media: ['https://m.media-amazon.com/images/I/71m9qQMPgFL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/71oKh5ETShL._AC_SX466_.jpg'] },
    { title: 'Impact Driver', description: 'High-torque impact driver for driving screws and bolts', media: ['https://m.media-amazon.com/images/I/81iNvQfH7gL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/619iurcED8L._AC_SX679_.jpg'] },
    { title: 'Angle Grinder', description: 'Powerful angle grinder for grinding and cutting', media: ['https://m.media-amazon.com/images/I/51eahVbzdSL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61t2sy3YZzL._AC_SX679_.jpg'] },
    { title: 'Table Saw', description: 'Large table saw for woodworking projects', media: ['https://m.media-amazon.com/images/I/71tgjjKcv-L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71AJlS4qvyL._AC_SX679_.jpg'] },
    { title: 'Miter Saw', description: 'Precision miter saw for angled cuts', media: ['https://m.media-amazon.com/images/I/71JGd3UiTRL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71Vkx91yAyL._AC_SX679_.jpg'] },
    { title: 'Rotary Tool', description: 'Versatile rotary tool for sanding, cutting, and engraving', media: ['https://m.media-amazon.com/images/I/712Ff5malcL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/91FftJ7318L._AC_SX679_.jpg'] },
    { title: 'Heat Gun', description: 'Adjustable heat gun for stripping paint and other tasks', media: ['https://m.media-amazon.com/images/I/61kEj+o6tQL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/71Sz5Rukk8L._AC_SX679_.jpg'] },
    { title: 'Soldering Iron', description: 'Electric soldering iron for electronic repairs', media: ['https://m.media-amazon.com/images/I/71yimJ+NaFL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/71r1mV1mH5L._AC_SX679_.jpg'] },
    { title: 'Combination Square', description: 'Multi-purpose combination square for measuring and marking', media: ['https://m.media-amazon.com/images/I/312iNTCUE5L._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/811r5bWvpxL._SX522_.jpg'] },
    { title: 'Carpenters Pencil', description: 'Durable pencil for marking wood and other materials', media: ['https://m.media-amazon.com/images/I/81eLZAbHHML.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71q8uVmpvcL._AC_SX466_.jpg'] },
    { title: 'C-Clamps', description: 'Strong C-clamps for holding materials in place', media: ['https://m.media-amazon.com/images/I/8139J2uXMTL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71aPBcUTJML._AC_SX679_.jpg'] },
    { title: 'Bar Clamps', description: 'Adjustable bar clamps for woodworking and assembly', media: ['https://m.media-amazon.com/images/I/71UYpgc6-HL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81rzUw14DNL._AC_SX679_.jpg'] },
    { title: 'G-Clamps', description: 'Heavy-duty G-clamps for securing workpieces', media: ['https://m.media-amazon.com/images/I/710MGTSxm8L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61UZ6PievmL._AC_SX679_.jpg'] },
    { title: 'Wood Rasp', description: 'Coarse wood rasp for shaping and smoothing wood', media: ['https://m.media-amazon.com/images/I/61cxQpKQoEL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61DTuYYbGdL._AC_SX679_.jpg'] },
    { title: 'Flat File', description: 'Flat file for smoothing metal and other materials', media: ['https://m.media-amazon.com/images/I/71mGV3zMs9L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71BPSf84waL._AC_SX679_.jpg'] },
    { title: 'Round File', description: 'Round file for enlarging holes and shaping curves', media: ['https://m.media-amazon.com/images/I/41fMVD2DJ8L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61Xu3e2rqUL._AC_SX679_.jpg'] },
    { title: 'Sandpaper Assortment', description: 'Variety pack of sandpaper for different grits', media: ['https://m.media-amazon.com/images/I/41PP0aIh8aL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61-P-QrLylL._SX522_.jpg'] },
    { title: 'Workbench', description: 'Sturdy workbench for all your projects', media: ['https://m.media-amazon.com/images/I/618vITicOHL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81etNsHTvRL._AC_SX679_.jpg'] },
    { title: 'Toolbox', description: 'Portable toolbox for organizing tools', media: ['https://m.media-amazon.com/images/I/81ctsQRl7eL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81Cm17mVasL._AC_SX679_.jpg'] },
    { title: 'Tool Belt', description: 'Convenient tool belt for carrying essentials', media: ['https://m.media-amazon.com/images/I/71w9dp+aDeL._AC_SX300_SY300_.jpg', 'https://m.media-amazon.com/images/I/71abOgzszQL._AC_SX679_.jpg'] },
    { title: 'Safety Goggles', description: 'Protective safety goggles for eye protection', media: ['https://m.media-amazon.com/images/I/71dkYvW25kL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/818AeSmnm2L._AC_SX679_.jpg'] },
    { title: 'Ear Protection', description: 'Noise-cancelling ear protection for loud environments', media: ['https://m.media-amazon.com/images/I/51bG7MeJKmL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61Vrh4epovL._AC_SX679_.jpg'] },
    { title: 'Work Gloves', description: 'Durable work gloves for hand protection', media: ['https://m.media-amazon.com/images/I/71jQo103aYL._AC_SX569_.jpg', 'https://m.media-amazon.com/images/I/71gbA3AZgtL._AC_SX569_.jpg'] },
    { title: 'Knee Pads', description: 'Comfortable knee pads for extended work', media: ['https://m.media-amazon.com/images/I/918SUjGqL7L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81aSP3tzuDL._AC_SX679_.jpg'] },
    { title: 'Dust Mask', description: 'Breathable dust mask for protection from particles', media: ['https://m.media-amazon.com/images/I/51-zA01VM0L._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71kGH27cAyL._SX522_.jpg'] },
    { title: 'Hard Hat', description: 'Impact-resistant hard hat for head protection', media: ['https://m.media-amazon.com/images/I/61Bb2fHXKLL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71yMktJdmzL._AC_SX679_.jpg'] },
    { title: 'Respirator', description: 'Advanced respirator for protection from fumes and dust', media: ['https://m.media-amazon.com/images/I/61XtPAT+93L._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/61VgB8zFnfL._AC_SX569_.jpg'] },
    { title: 'Utility Apron', description: 'Heavy-duty utility apron with multiple pockets', media: ['https://m.media-amazon.com/images/I/81wr3MTAr8L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81SnmSC3HNL._AC_SY879_.jpg'] },
    { title: 'Extension Cord', description: 'Long extension cord for powering tools at a distance', media: ['https://m.media-amazon.com/images/I/61snPWDxzzL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71rK8sHxufL._AC_SX466_.jpg'] },
    { title: 'Work Light', description: 'Bright work light for illuminating your workspace', media: ['https://m.media-amazon.com/images/I/61tT1KI5PlL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71YNBHQf+IL._AC_SX679_.jpg'] },
    { title: 'Ladder', description: 'Sturdy ladder for reaching high places', media: ['https://m.media-amazon.com/images/I/71B7tmfBv6L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71G-TaBnCvL._AC_SX679_.jpg'] },
    { title: 'Step Stool', description: 'Compact step stool for easy access to elevated areas', media: ['https://m.media-amazon.com/images/I/61tRnD2doxL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71TUPsztExL._AC_SX679_.jpg'] },
    { title: 'Extension Ladder', description: 'Adjustable extension ladder for extended reach', media: ['https://m.media-amazon.com/images/I/61QZzN5+1vL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/71jBZ2+IuxL._AC_SX679_.jpg'] },
    { title: 'Sawhorse', description: 'Durable sawhorse for supporting workpieces', media: ['https://m.media-amazon.com/images/I/61WySW68U-L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71sDKG44f1L._AC_SX679_.jpg'] },
    { title: 'Folding Workbench', description: 'Portable folding workbench for on-the-go projects', media: ['https://m.media-amazon.com/images/I/71m6C34VnrL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71JkiNjKGlL._AC_SX679_.jpg'] },
    { title: 'Tool Organizer', description: 'Wall-mounted tool organizer for easy access', media: ['https://m.media-amazon.com/images/I/81wRxczINnL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/9140yTMMEoL._AC_SX679_.jpg'] },
    { title: 'Magnetic Tool Holder', description: 'Magnetic tool holder for quick storage', media: ['https://m.media-amazon.com/images/I/513ozkjjvGL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71uDRc46PwL._AC_SX679_.jpg'] },
    { title: 'Tool Chest', description: 'Large tool chest for comprehensive tool storage', media: ['https://m.media-amazon.com/images/I/71-ouJPDYhL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71NQnEueABL._AC_SX679_.jpg'] },
    { title: 'Drill Bit Set', description: 'Assorted drill bit set for various materials', media: ['https://m.media-amazon.com/images/I/81+SvTR3+JL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/81wioUD3ssL._AC_SX679_.jpg'] },
    { title: 'Hole Saw Kit', description: 'Complete hole saw kit for cutting large holes', media: ['https://m.media-amazon.com/images/I/51wynj3sddL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71IxXiZbnFL._SX522_.jpg'] },
    { title: 'Wood Router', description: 'Powerful wood router for shaping and trimming', media: ['https://m.media-amazon.com/images/I/51u4TdCO0lL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71E9xdt8eML._AC_SX679_.jpg'] },
    { title: 'Belt Sander', description: 'Electric belt sander for smoothing surfaces', media: ['https://m.media-amazon.com/images/I/7154x92t4kL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81f0zV6-5FL._AC_SX679_.jpg'] },
    { title: 'Orbital Sander', description: 'Random orbital sander for a smooth finish', media: ['https://m.media-amazon.com/images/I/61gLO6tD4UL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/511JpjT5GfL._AC_SX679_.jpg'] },
    { title: 'Palm Sander', description: 'Compact palm sander for detailed work', media: ['https://m.media-amazon.com/images/I/614hw+xGqqL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/61GYqcSZAHL._AC_SX679_.jpg'] },
    { title: 'Bench Grinder', description: 'Sturdy bench grinder for sharpening tools', media: ['https://m.media-amazon.com/images/I/71RkIjRxEtL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71t3cA4WuxL._AC_SX679_.jpg'] },
    { title: 'Chop Saw', description: 'Heavy-duty chop saw for cutting metal and wood', media: ['https://m.media-amazon.com/images/I/516DPmowaZL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61mfozi-qEL._AC_SX679_.jpg'] },
    { title: 'Reciprocating Saw', description: 'Versatile reciprocating saw for demolition work', media: ['https://m.media-amazon.com/images/I/61kKygrI4TL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/51nm+HzJr5L._AC_SX679_.jpg'] },
    { title: 'Planer', description: 'Electric planer for smoothing and leveling wood', media: ['https://m.media-amazon.com/images/I/615gGtCh5NL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/51XB-L-Z-6L._AC_SX679_.jpg'] },
    { title: 'Nail Gun', description: 'Pneumatic nail gun for fast and efficient nailing', media: ['https://m.media-amazon.com/images/I/81JDHz6fLtL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71-oAwe2UbL._AC_SX466_.jpg'] },
    { title: 'Staple Gun', description: 'Electric staple gun for upholstery and crafts', media: ['https://m.media-amazon.com/images/I/61B2TFDpMlL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61Dap3N3VpL._AC_SX466_.jpg'] },
    { title: 'Brad Nailer', description: 'Precision brad nailer for trim work', media: ['https://m.media-amazon.com/images/I/61T322zrfmL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71ecy4FYRlL._AC_SX679_.jpg'] },
    { title: 'Finish Nailer', description: 'Finish nailer for carpentry and finishing tasks', media: ['https://m.media-amazon.com/images/I/61p5o9ddMPL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61jyLia1oTL._AC_SX679_.jpg'] },
    { title: 'Palm Nailer', description: 'Compact palm nailer for tight spaces', media: ['https://m.media-amazon.com/images/I/71e4QBSXUaL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71BgqlVUJaL._AC_SX679_.jpg'] },
    { title: 'Air Compressor', description: 'Portable air compressor for powering pneumatic tools', media: ['https://m.media-amazon.com/images/I/71BSPHh9Q0L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61CzbyxsRKL._AC_SX679_.jpg'] },
    { title: 'Air Hose', description: 'Flexible air hose for connecting pneumatic tools', media: ['https://m.media-amazon.com/images/I/61BmmE3TnTL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61Bj+P-Jb3L._AC_SX679_.jpg'] },
    { title: 'Air Tool Kit', description: 'Complete air tool kit for various applications', media: ['https://m.media-amazon.com/images/I/81IXzEeQudL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/81BelRXV4OL.__AC_SY300_SX300_QL70_FMwebp_.jpg'] },
    { title: 'Shop Vacuum', description: 'Powerful shop vacuum for cleaning up debris', media: ['https://m.media-amazon.com/images/I/61dWWfPxfQL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71xANU3Mj-L._AC_SX679_.jpg'] },
    { title: 'Dust Collector', description: 'Efficient dust collector for woodworking shops', media: ['https://m.media-amazon.com/images/I/61xiZoGu6xS.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71ukUVXuxeL._AC_SX679_.jpg'] },
    { title: 'Blower', description: 'Electric blower for clearing leaves and debris', media: ['https://m.media-amazon.com/images/I/71Apl1BHUPL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81fBgiBMDCL._AC_SX679_.jpg'] },
    { title: 'Pressure Washer', description: 'High-pressure washer for cleaning surfaces', media: ['https://m.media-amazon.com/images/I/71QvIwb6ahL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81SnAGgTJmL._AC_SX679_.jpg'] },
    { title: 'Power Washer', description: 'Gas-powered washer for heavy-duty cleaning', media: ['https://m.media-amazon.com/images/I/718rtiNuh6L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71m2Tl5ML6L._AC_SX679_.jpg'] },
    { title: 'Paint Sprayer', description: 'Electric paint sprayer for smooth and even coverage', media: ['https://m.media-amazon.com/images/I/617t6Ti5pLL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71Zo-NMWnTL._AC_SX679_.jpg'] },
    { title: 'Caulking Gun', description: 'Manual caulking gun for sealing joints', media: ['https://m.media-amazon.com/images/I/61EQ+H2sE0L._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/716esq+5fbL._AC_SX679_.jpg'] },
    { title: 'Putty Knife', description: 'Flexible putty knife for spreading and scraping', media: ['https://m.media-amazon.com/images/I/61qBVm7Rf1L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61fXAXK2i8L._AC_SX679_.jpg'] },
    { title: 'Painters Tape', description: 'High-quality painters tape for clean lines', media: ['https://m.media-amazon.com/images/I/41nZpaJSzQL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61m-bnYdbpL._SX522_.jpg'] },
    { title: 'Paint Roller', description: 'Durable paint roller for even application', media: ['https://m.media-amazon.com/images/I/71QZSL63XJL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81H4fiePfYL._AC_SX679_.jpg'] },
    { title: 'Paint Tray', description: 'Sturdy paint tray for holding paint and rollers', media: ['https://m.media-amazon.com/images/I/71Br9Hl2CFL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/81D86IacnCL._AC_SX679_.jpg'] },
    { title: 'Paintbrush Set', description: 'Set of paintbrushes for detailed painting', media: ['https://m.media-amazon.com/images/I/71JEXuFLJPL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71lMvpYIUSL._AC_SX679_.jpg'] },
    { title: 'Drop Cloth', description: 'Protective drop cloth for covering surfaces', media: ['https://m.media-amazon.com/images/I/71-8ayBX5VL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81j9gEv4jtL._AC_SX679_.jpg'] },
    { title: 'Lawn Mower', description: 'Gas-powered lawn mower for cutting grass', media: ['https://m.media-amazon.com/images/I/51I8NfZeCyS.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/616BtWwlH3S._AC_SX679_.jpg'] },
    { title: 'Electric Lawn Mower', description: 'Eco-friendly electric lawn mower', media: ['https://m.media-amazon.com/images/I/51QofBq3BrL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/610p86psDpL._AC_SX679_.jpg'] },
    { title: 'String Trimmer', description: 'Cordless string trimmer for edging and trimming', media: ['https://m.media-amazon.com/images/I/61a1lOmJdNL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81m5hNXEAeL._AC_SX679_.jpg'] },
    { title: 'Hedge Trimmer', description: 'Electric hedge trimmer for shaping bushes', media: ['https://m.media-amazon.com/images/I/61qNJClJ2UL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/616s6F7pgjL._AC_SX679_.jpg'] },
    { title: 'Leaf Blower', description: 'High-speed leaf blower for clearing debris', media: ['https://m.media-amazon.com/images/I/71m9PcGevSL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/51XvOxfx-FL._AC_.jpg'] },
    { title: 'Chainsaw', description: 'Powerful chainsaw for cutting trees and branches', media: ['https://m.media-amazon.com/images/I/61vXLawhV1L.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61gnCtuf3GL._AC_SX679_.jpg'] },
    { title: 'Garden Shovel', description: 'Heavy-duty garden shovel for digging', media: ['https://m.media-amazon.com/images/I/61itLoCAIlL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61vemSxhZAL._AC_SY879_.jpg'] }
  ],

  'Automotive Parts & Accessories' => [
    { title: 'Car Battery', description: 'Long-lasting car battery', media: ['https://m.media-amazon.com/images/I/71QuCK6A4QL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/71FJk24FzUL._AC_SX466_.jpg'] },
    { title: 'Brake Pads', description: 'High-quality brake pads for cars', media: ['https://m.media-amazon.com/images/I/71Kvb9Xt3cL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61VP4Pv29SL._AC_SX466_.jpg'] },
    { title: 'Oil Filter', description: 'Filter for cleaning engine oil', media: ['https://m.media-amazon.com/images/I/51wzWrbA9nL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/41Iizuq8LxL._AC_SX466_.jpg'] },
    { title: 'Air Filter', description: 'Filter for cleaning air entering the engine', media: ['https://m.media-amazon.com/images/I/61S99C2TF-L.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/811mPx9BCoL._AC_SX466_.jpg'] },
    { title: 'Fuel Filter', description: 'Filter for cleaning fuel', media: ['https://m.media-amazon.com/images/I/61ligXGD-5L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61RoKZGmukL._AC_SX466_.jpg'] },
    { title: 'Spark Plugs', description: 'Spark plugs for ignition systems', media: ['https://m.media-amazon.com/images/I/61Ch4W9B97L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61qzZXZ0E2S._AC_SX466_PIbundle-16,TopRight,0,0_SH20_.jpg'] },
    { title: 'Headlights', description: 'Replacement headlights for vehicles', media: ['https://m.media-amazon.com/images/I/81Uf7yZBMXL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71fjeGyr1QL._AC_SX466_.jpg'] },
    { title: 'Tail Lights', description: 'Replacement tail lights for vehicles', media: ['https://m.media-amazon.com/images/I/71jhphPYQnL._AC_SX466_PIbundle-2,TopRight,0,0_SH20_.jpg', 'https://m.media-amazon.com/images/I/814ZRDNtXwL._AC_SX466_.jpg'] },
    { title: 'Alternator', description: 'Alternator for charging the vehicle battery', media: ['https://m.media-amazon.com/images/I/61fJRgQYL3L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61OSTFmGavL._AC_SX466_.jpg'] },
    { title: 'Starter Motor', description: 'Starter motor for starting the engine', media: ['https://m.media-amazon.com/images/I/71UOQeLc0sL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/31aCVyYm8tL._AC_.jpg'] },
    { title: 'Water Pump', description: 'Water pump for cooling system', media: ['https://m.media-amazon.com/images/I/61yaqRzwJkL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/517Edq8vpkL._AC_SX679_.jpg'] },
    { title: 'Radiator', description: 'Radiator for cooling the engine', media: ['https://m.media-amazon.com/images/I/813ahPWXjYL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81WOIAaXMML._AC_SX466_.jpg'] },
    { title: 'Timing Belt', description: 'Timing belt for engine synchronization', media: ['https://m.media-amazon.com/images/I/61PEvkaxofL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/51jytyXtniL._AC_SX466_.jpg'] },
    { title: 'Timing Chain', description: 'Timing chain for engine synchronization', media: ['https://m.media-amazon.com/images/I/61zskBy537L._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/61Hj9sBvTYL._AC_SX466_.jpg'] },
    { title: 'Transmission Filter', description: 'Filter for cleaning transmission fluid', media: ['https://m.media-amazon.com/images/I/714OWwmj4VL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81WVwrZ0e3L._AC_SX466_.jpg'] },
    { title: 'Power Steering Pump', description: 'Pump for power steering system', media: ['https://m.media-amazon.com/images/I/61HXQ5URlfL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61RCdq4QDgL.__AC_SX300_SY300_QL70_FMwebp_.jpg'] },
    { title: 'Brake Rotors', description: 'Rotors for braking system', media: ['https://m.media-amazon.com/images/I/81fVHOvyh8L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71FTq5Q-6rL._AC_SX466_.jpg'] },
    { title: 'Clutch Kit', description: 'Complete clutch kit for manual transmission', media: ['https://m.media-amazon.com/images/I/71yQ0S--5nL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/711Z5WgFI4L._AC_SX466_.jpg'] },
    { title: 'Suspension Struts', description: 'Suspension struts for vehicle stability', media: ['https://m.media-amazon.com/images/I/71mHD4LFvBL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71gLhDdgKwL.__AC_SX300_SY300_QL70_FMwebp_.jpg'] },
    { title: 'Shock Absorbers', description: 'Shock absorbers for smooth driving', media: ['https://m.media-amazon.com/images/I/61rUgFopq1L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/6126Qp9nYCL._AC_SX466_.jpg'] },
    { title: 'Fuel Pump', description: 'Pump for delivering fuel to the engine', media: ['https://m.media-amazon.com/images/I/51D0PpwAl6L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/51zQiwKhrwL._AC_SX466_.jpg'] },
    { title: 'Battery Charger', description: 'Charger for maintaining car battery', media: ['https://m.media-amazon.com/images/I/71hqXWEqiWL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81dOFbll55L.__AC_SX300_SY300_QL70_FMwebp_.jpg'] },
    { title: 'Car Filters', description: 'Various filters for vehicle maintenance', media: ['https://m.media-amazon.com/images/I/61IM1WadFNL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/51B6XLUGSnL._AC_SX466_.jpg'] },
    { title: 'Brake Calipers', description: 'Calipers for the braking system', media: ['https://m.media-amazon.com/images/I/71dLDPWWqvL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71ESRtt2EcL.__AC_SX300_SY300_QL70_FMwebp_.jpg'] },
    { title: 'Wheel Bearings', description: 'Bearings for wheel rotation', media: ['https://m.media-amazon.com/images/I/71eaqeGGAXL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61jK3CdxbOL._AC_SX466_.jpg'] },
    { title: 'Drive Belts', description: 'Belts for powering accessories', media: ['https://m.media-amazon.com/images/I/41Y0ZGsqt7L._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71sIegyM8lL._SX425_.jpg'] },
    { title: 'Serpentine Belt', description: 'Belt for driving multiple accessories', media: ['https://m.media-amazon.com/images/I/31ysKYDJF2S._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/41O4N7pe8+S._SX522_.jpg'] },
    { title: 'Fuel Injectors', description: 'Injectors for delivering fuel into the engine', media: ['https://m.media-amazon.com/images/I/61AQuFuXHHL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71vDIHUj5LL._AC_SX466_.jpg'] },
    { title: 'Radiator Hoses', description: 'Hoses for connecting radiator to engine', media: ['https://m.media-amazon.com/images/I/61A4lEVUJqL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71KYNfeRbhL._AC_SX679_.jpg'] },
    { title: 'Car Thermostat', description: 'Thermostat for regulating engine temperature', media: ['https://m.media-amazon.com/images/I/91oO74rnDoL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/91DxzluUlwL._AC_SX466_.jpg'] },
    { title: 'Cylinder Head', description: 'Head for engine cylinder block', media: ['https://m.media-amazon.com/images/I/61uBtgsd1cL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/7103fTDWteL._AC_SX466_.jpg'] },
    { title: 'Engine Block', description: 'Engine block for housing engine components', media: ['https://m.media-amazon.com/images/I/81dF8dIQ59L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81WoFTa8u8L._AC_SX679_.jpg'] },
    { title: 'Piston Rings', description: 'Rings for sealing pistons in the engine', media: ['https://m.media-amazon.com/images/I/81yZy43MEjL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71FrcO2FneL._AC_SX466_.jpg'] },
    { title: 'Crankshaft', description: 'Crankshaft for converting piston movement', media: ['https://m.media-amazon.com/images/I/61eZmYsSHZL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/61fYG-fmZAL._AC_SX466_.jpg'] },
    { title: 'Camshaft', description: 'Camshaft for operating engine valves', media: ['https://m.media-amazon.com/images/I/51Y78+vr5kL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/61TUb6rw4dL._AC_SX466_.jpg'] },
    { title: 'Turbocharger', description: 'Turbocharger for increasing engine power', media: ['https://m.media-amazon.com/images/I/71rhG9wYJJL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81iSKLZgkuL._AC_SX466_.jpg'] },
    { title: 'Supercharger', description: 'Supercharger for boosting engine performance', media: ['https://m.media-amazon.com/images/I/71Bz4nK9FvL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81ByXyFcNoL._AC_SX466_.jpg'] },
    { title: 'Exhaust Manifold', description: 'Manifold for directing exhaust gases', media: ['https://m.media-amazon.com/images/I/81KORsS-nJL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81vATVFkS4L._AC_SX466_.jpg'] },
    { title: 'Intake Manifold', description: 'Manifold for distributing air-fuel mixture', media: ['https://m.media-amazon.com/images/I/61+7QECdc7L._AC_SX300_SY300_.jpg', 'https://m.media-amazon.com/images/I/813gtYDDmQL._AC_SX466_.jpg'] },
    { title: 'Catalytic Converter', description: 'Converter for reducing exhaust emissions', media: ['https://m.media-amazon.com/images/I/71IBTJmSORL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71ofUv1GG7L._AC_SX466_.jpg'] },
    { title: 'Oxygen Sensors', description: 'Sensors for monitoring exhaust gases', media: ['https://m.media-amazon.com/images/I/61EEKMJiFSL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61xuywZ8taL._AC_SX466_.jpg'] },
    { title: 'Mass Air Flow Sensor', description: 'Sensor for measuring air flow into the engine', media: ['https://m.media-amazon.com/images/I/51YWxO28QsL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71Zg56Gf58L._AC_SX466_.jpg'] },
    { title: 'Idle Air Control Valve', description: 'Valve for controlling engine idle speed', media: ['https://m.media-amazon.com/images/I/51EeU3zOAfL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61-BVnLr82L._AC_SX466_.jpg'] },
    { title: 'PCV Valve', description: 'Valve for controlling crankcase ventilation', media: ['https://m.media-amazon.com/images/I/6168uFeYEgL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/510eQ1XecYL._AC_SX466_.jpg'] },
    { title: 'EGR Valve', description: 'Valve for recirculating exhaust gases', media: ['https://m.media-amazon.com/images/I/71X8jxLxVCL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61OqMgZy1ZL._AC_SX466_.jpg'] },
    { title: 'Fuel Tank', description: 'Tank for storing fuel', media: ['https://m.media-amazon.com/images/I/614nMDoTFGL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61qlh374MBL._AC_SX466_.jpg'] },
    { title: 'Fuel Tank Sender', description: 'Sender for fuel level measurement', media: ['https://m.media-amazon.com/images/I/61Vf2F2y-1L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/6168oxwSE+L._AC_SX466_.jpg'] },
    { title: 'Fuel Filler Cap', description: 'Cap for sealing the fuel tank', media: ['https://m.media-amazon.com/images/I/71k3ME3IAgL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71roz91N-CL._AC_SX466_.jpg'] },
    { title: 'Power Window Motor', description: 'Motor for operating power windows', media: ['https://m.media-amazon.com/images/I/71CMQ2NvnyL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81mOj+0CFML._AC_SX466_.jpg'] },
    { title: 'Door Lock Actuator', description: 'Actuator for locking and unlocking doors', media: ['https://m.media-amazon.com/images/I/71M3MpEPvCL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71LaN44O0lL._AC_SX466_.jpg'] },
    { title: 'Window Regulator', description: 'Regulator for operating window movement', media: ['https://m.media-amazon.com/images/I/71oMI++ORZL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/61IlbhlFofL.__AC_SX300_SY300_QL70_FMwebp_.jpg'] },
    { title: 'Ignition Coil', description: 'Coil for igniting the air-fuel mixture', media: ['https://m.media-amazon.com/images/I/61L12Av7nVL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61AkRsNuNgL.__AC_SX300_SY300_QL70_FMwebp_.jpg'] },
    { title: 'Distributor Cap', description: 'Cap for distributing electrical current', media: ['https://m.media-amazon.com/images/I/61eDVyCU-6L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/714UlVaz-iL._AC_SX466_.jpg'] },
    { title: 'Rotor Arm', description: 'Arm for distributing electrical current', media: ['https://m.media-amazon.com/images/I/71-aJy1qvZL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71--axZ2MlL._AC_SX466_.jpg'] },
    { title: 'Wiper Blades', description: 'Blades for cleaning the windshield', media: ['https://m.media-amazon.com/images/I/71pdRqLR+FL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/81d8SPbgoQL._AC_SX466_.jpg'] },
    { title: 'Wiper Motor', description: 'Motor for operating windshield wipers', media: ['https://m.media-amazon.com/images/I/71pLhAe6JwL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/715awe6pcuL.__AC_SX300_SY300_QL70_FMwebp_.jpg'] },
    { title: 'Windshield Washer Pump', description: 'Pump for windshield washer fluid', media: ['https://m.media-amazon.com/images/I/71bUajhG5uL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/716C0mXP09L._AC_SX466_.jpg'] },
    { title: 'Head Gasket', description: 'Gasket for sealing the engine head', media: ['https://m.media-amazon.com/images/I/715THDNYNWL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/612+bRAb2QL._AC_SX466_.jpg'] },
    { title: 'Valve Cover Gasket', description: 'Gasket for sealing the valve cover', media: ['https://m.media-amazon.com/images/I/71SRxe7bErL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/619kN3P9BqL._AC_SX466_.jpg'] },
    { title: 'Oil Pan Gasket', description: 'Gasket for sealing the oil pan', media: ['https://m.media-amazon.com/images/I/61ZpbmPx4RL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61h0hKKlkmL._AC_SX679_.jpg'] },
    { title: 'Transmission Pan Gasket', description: 'Gasket for sealing the transmission pan', media: ['https://m.media-amazon.com/images/I/71jEzkgvvXL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71U1yS6d4TL.__AC_SX300_SY300_QL70_FMwebp_.jpg'] },
    { title: 'Differential Fluid', description: 'Fluid for lubricating the differential', media: ['https://m.media-amazon.com/images/I/41PQuyd9XYL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71rEP3gLuaL._AC_SY879_.jpg'] },
    { title: 'Gear Oil', description: 'Oil for lubricating gear systems', media: ['https://m.media-amazon.com/images/I/714wyQak6AL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/91K1rUFSWEL._AC_SX466_.jpg'] },
    { title: 'Transmission Fluid', description: 'Fluid for transmission lubrication', media: ['https://m.media-amazon.com/images/I/61JaVInpNPL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71QO4+OPyjL._AC_SX466_.jpg'] },
    { title: 'Brake Fluid', description: 'Fluid for the braking system', media: ['https://m.media-amazon.com/images/I/41UR0JGvL8L._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71VBLLa50HL._SX522_.jpg'] },
    { title: 'Coolant', description: 'Coolant for engine temperature regulation', media: ['https://m.media-amazon.com/images/I/81h2wnVpZnL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81rKxukPBNL._AC_SX466_.jpg'] },
    { title: 'Engine Oil', description: 'Oil for engine lubrication', media: ['https://m.media-amazon.com/images/I/71QCVmicA6L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81cY6DSUBLL._AC_SX466_.jpg'] },
    { title: 'Cabin Air Filter', description: 'Filter for air inside the vehicle cabin', media: ['https://m.media-amazon.com/images/I/81k8lSgC9KL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81pXL2VkCFL._AC_SX466_.jpg'] },
    { title: 'Engine Mounts', description: 'Mounts for securing the engine', media: ['https://m.media-amazon.com/images/I/61naJZqkXuL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61CI--Mq2cL._AC_SX466_.jpg'] },
    { title: 'Transmission Mounts', description: 'Mounts for securing the transmission', media: ['https://m.media-amazon.com/images/I/61ZXe3vcT0L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71zhBnlH97L._AC_SX466_.jpg'] },
    { title: 'Suspension Bushings', description: 'Bushings for suspension system', media: ['https://m.media-amazon.com/images/I/71MHfU1XX6L.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61Zh29kXW+L._AC_SY300_SX300_.jpg'] },
    { title: 'Tie Rod Ends', description: 'Ends for steering linkage', media: ['https://m.media-amazon.com/images/I/61BS8dr+R1L._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/51AxSbIk0SL._AC_SX466_.jpg'] },
    { title: 'Ball Joints', description: 'Joints for suspension and steering', media: ['https://m.media-amazon.com/images/I/71FgwdC-2gL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71Ln40-aahL._AC_SX466_.jpg'] },
    { title: 'Control Arms', description: 'Arms for controlling wheel movement', media: ['https://m.media-amazon.com/images/I/61T2KTyfbYL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/91PmRWmVObL._AC_SX466_.jpg'] },
    { title: 'Strut Mounts', description: 'Mounts for struts in the suspension', media: ['https://m.media-amazon.com/images/I/51Drf0v-LdL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71yRzVdgbWL._AC_SX679_.jpg'] },
    { title: 'Shock Absorber Mounts', description: 'Mounts for shock absorbers', media: ['https://m.media-amazon.com/images/I/51Zn4h-NE6L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71UooMLbdiL._AC_SX466_.jpg'] },
    { title: 'Leaf Springs', description: 'Springs for vehicle suspension', media: ['https://m.media-amazon.com/images/I/61CTKr2cqOL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61jIqtq3JpL._AC_SX466_.jpg'] },
    { title: 'Coil Springs', description: 'Springs for vehicle suspension', media: ['https://m.media-amazon.com/images/I/91qkOlLRu4L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81sX-0W-LSL._AC_SX466_.jpg']   },
    { title: 'Anti-Sway Bars', description: 'Bars for reducing body roll', media: ['https://m.media-amazon.com/images/I/71jWrMIRaLL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/813jWPWwd6L._AC_SX466_.jpg']   },
    { title: 'Drive Shafts', description: 'Shafts for transferring power from the engine', media: ['https://m.media-amazon.com/images/I/61XMV3gQl5L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71sLh2pjN2L._AC_SX466_.jpg']   },
    { title: 'Axle Shafts', description: 'Shafts for transferring power to the wheels', media: ['https://m.media-amazon.com/images/I/71cfTCRB-QL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71xORkVADWL._AC_SX679_.jpg']   },
    { title: 'Differential Gears', description: 'Gears for the differential system', media: ['https://m.media-amazon.com/images/I/61AoTpgyw3L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61iHeSsBJbS.__AC_SX300_SY300_QL70_FMwebp_.jpg']   },
    { title: 'Wheel Hubs', description: 'Hubs for mounting wheels', media: ['https://m.media-amazon.com/images/I/719CKQQvY1L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71Y8KRx44dL._AC_SX679_.jpg']   },
    { title: 'Wheel Studs', description: 'Studs for securing wheels', media: ['https://m.media-amazon.com/images/I/61LHAx-pCkL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/619RMOWX4WL._AC_SX466_.jpg']   },
    { title: 'Lug Nuts', description: 'Nuts for securing wheels' , media: ['https://m.media-amazon.com/images/I/71m4qhQzTsL._AC_SX466_PIbundle-24,TopRight,0,0_SH20_.jpg', 'https://m.media-amazon.com/images/I/71P4Wo5dsRL.__AC_SX300_SY300_QL70_FMwebp_.jpg']  },
    { title: 'Wheel Spacers', description: 'Spacers for adjusting wheel offset', media: ['https://m.media-amazon.com/images/I/81bWfEWi80L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71a0MDhsvYL.__AC_SX300_SY300_QL70_FMwebp_.jpg']   },
    { title: 'Tire Pressure Sensors', description: 'Sensors for monitoring tire pressure', media: ['https://m.media-amazon.com/images/I/61PE4yagEDL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61DJBGFhqLL.__AC_SX300_SY300_QL70_FMwebp_.jpg']   },
    { title: 'Oil Cooler', description: 'Cooler for regulating engine oil temperature', media: ['https://m.media-amazon.com/images/I/71fVeF4GJzL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71JJhVkg8vL._AC_SX466_.jpg']   },
    { title: 'Transmission Cooler', description: 'Cooler for regulating transmission fluid temperature', media: ['https://m.media-amazon.com/images/I/71Mzlv4D2NL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71q1DR+A3oL._AC_SX466_.jpg']   },
    { title: 'Intercooler', description: 'Cooler for reducing intake air temperature', media: ['https://m.media-amazon.com/images/I/7142qpLiXfL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71f+6L2oaIL._AC_SX466_.jpg']   },
    { title: 'Turbocharger Kits', description: 'Kits for installing turbochargers', media: ['https://m.media-amazon.com/images/I/71rhG9wYJJL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71dSAtYt9qL.__AC_SX300_SY300_QL70_FMwebp_.jpg']   },
    { title: 'Supercharger Kits', description: 'Kits for installing superchargers', media: ['https://m.media-amazon.com/images/I/51O-MFl9W-L._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/412ixCN2FfL._AC_SX466_.jpg']   },
    { title: 'Engine Rebuild Kits', description: 'Kits for rebuilding engines', media: ['https://m.media-amazon.com/images/I/81kB15VhqXL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/713dP2tFwbL._AC_SX466_PIbundle-26,TopRight,0,0_SH20_.jpg']   },
    { title: 'Cylinder Heads', description: 'Heads for engine cylinders', media: ['https://m.media-amazon.com/images/I/61gwxembSEL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/614hNhjF2tL._AC_SX466_.jpg']   },
    { title: 'Pistons', description: 'Pistons for engine cylinders', media: ['https://m.media-amazon.com/images/I/81-EG45FQxL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71AP97+Mz3L._AC_SX466_.jpg']   },
    { title: 'Connecting Rods', description: 'Rods for connecting pistons to the crankshaft', media: ['https://m.media-amazon.com/images/I/61Dc7VT65+L._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/51ihdJPSeHL._AC_SX466_.jpg']   },
    { title: 'Crankshafts', description: 'Crankshafts for converting piston movement', media: ['https://m.media-amazon.com/images/I/61kt7XcRasL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71kPb4wNVFL._AC_SX466_.jpg']   },
    { title: 'Camshafts', description: 'Camshafts for operating engine valves', media: ['https://m.media-amazon.com/images/I/61WYF3XVzZL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/61+VzMRQYJL._AC_SX466_.jpg']   },
    { title: 'Water Pump Pulley', description: 'Pulley for driving the water pump', media: ['https://m.media-amazon.com/images/I/9150O9pT1HL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71kX8SUyPLL._AC_SY879_.jpg']   },
    { title: 'Alternator Pulley', description: 'Pulley for driving the alternator', media: ['https://m.media-amazon.com/images/I/71Bmyo2B6+L._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/91VLZiBANXL.__AC_SX300_SY300_QL70_FMwebp_.jpg']   },
    { title: 'Power Steering Pulley', description: 'Pulley for driving the power steering pump', media: ['https://m.media-amazon.com/images/I/81xG5wi7-3L.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/91sWRcBQq9L.__AC_SY300_SX300_QL70_FMwebp_.jpg']   }
  ],

  'Computer Parts & Accessories' => [
    { title: 'Graphics Card', description: 'High-performance graphics card for gaming', media: ['https://m.media-amazon.com/images/I/71tduSp8ooL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/91XE5KmyNFL._AC_SX679_.jpg']  },
    { title: 'RAM Module', description: '8GB RAM module for computers', media: ['https://m.media-amazon.com/images/I/81UN8XaAvEL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81TPGZTTp-L._AC_SX466_.jpg']  },
    { title: 'Solid State Drive', description: '500GB SSD for faster storage', media: ['https://m.media-amazon.com/images/I/51zhuXxYuRL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61MOAo9OF2L._AC_SX466_.jpg']  },
    { title: 'Hard Disk Drive', description: '1TB HDD for additional storage', media: ['https://m.media-amazon.com/images/I/716jHJbwziL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/81OvSTN59UL._AC_SX466_.jpg']  },
    { title: 'Motherboard', description: 'ATX motherboard with multiple ports', media: ['https://m.media-amazon.com/images/I/81Z-f4nZ9bL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81S9D7bqEzL.__AC_SX300_SY300_QL70_FMwebp_.jpg']  },
    { title: 'Processor', description: 'Intel i7 processor for high-speed computing', media: ['https://m.media-amazon.com/images/I/51CUAct4KVL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61o3Qs1wbXL.__AC_SX300_SY300_QL70_FMwebp_.jpg']  },
    { title: 'Power Supply Unit', description: '650W PSU for reliable power delivery', media: ['https://m.media-amazon.com/images/I/41jgzVUXf1L._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71uJg82IdtL._SX522_.jpg']  },
    { title: 'CPU Cooler', description: 'High-performance CPU cooler for overclocking', media: ['https://m.media-amazon.com/images/I/41hFTmi5aUL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71ew-piKtHL._SX522_.jpg']  },
    { title: 'Computer Case', description: 'Mid-tower case with cable management', media: ['https://m.media-amazon.com/images/I/71J4iohAlaL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81XN95aqKOL._AC_SX466_.jpg']  },
    { title: 'Gaming Keyboard', description: 'Mechanical keyboard with RGB lighting', media: ['https://m.media-amazon.com/images/I/71QDJHG1PqL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71-JYMSXBdL._AC_SX466_.jpg']  },
    { title: 'Gaming Mouse', description: 'Ergonomic mouse with customizable DPI settings', media: ['https://m.media-amazon.com/images/I/61kI0PIuXVL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71mA3cfWVdL._AC_SX466_.jpg']  },
    { title: 'Monitor', description: '27-inch 4K monitor for sharp visuals', media: ['https://m.media-amazon.com/images/I/71P0M7tKjYL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61EfXRGhuXL._AC_SX466_.jpg']  },
    { title: 'Headset', description: 'Gaming headset with surround sound', media: ['https://m.media-amazon.com/images/I/61CGHv6kmWL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71z2WmHMtZL._AC_SX466_.jpg']  },
    { title: 'Webcam', description: '1080p webcam for clear video calls', media: ['https://m.media-amazon.com/images/I/71A0Pp767BL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/615EdxQ6DuL._AC_SX466_.jpg']  },
    { title: 'External Hard Drive', description: '2TB external drive for backup', media: ['https://m.media-amazon.com/images/I/61H0+cBODcL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/71tWuOlVFDL._AC_SX466_.jpg']  },
    { title: 'USB Hub', description: '7-port USB hub for connecting multiple devices', media: ['https://m.media-amazon.com/images/I/61cg1AdFLoL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71Gs7LSNa2L._AC_SX466_.jpg']  },
    { title: 'Optical Drive', description: 'DVD-RW drive for reading and writing discs', media: ['https://m.media-amazon.com/images/I/61SHnK1hFsL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61zDCqdhMgL._AC_SX466_.jpg']  },
    { title: 'Network Card', description: 'Dual-band Wi-Fi card for faster internet', media: ['https://m.media-amazon.com/images/I/514NtDtUZtL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/519ZsoV5dvL._AC_SX466_.jpg']  },
    { title: 'Sound Card', description: 'External sound card for enhanced audio quality', media: ['https://m.media-amazon.com/images/I/71mULYdFxvL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/714jzdHg91L._AC_SX466_.jpg']  },
    { title: 'Cooling Fan', description: '120mm cooling fan for improved airflow', media: ['https://m.media-amazon.com/images/I/41t+b0-O50L._SX342_SY445_.jpg', 'https://m.media-amazon.com/images/I/61L9AYxldpL._SX522_.jpg']  },
    { title: 'Thermal Paste', description: 'High-performance thermal paste for CPUs', media: ['https://m.media-amazon.com/images/I/51PWVs6aNmL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81y2rLHMK7L._AC_SX466_.jpg']  },
    { title: 'Mouse Pad', description: 'Large mouse pad with smooth surface', media: ['https://m.media-amazon.com/images/I/71JcNHOlQaL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71++aDtp+RL._AC_SX466_.jpg']  },
    { title: 'Power Strip', description: 'Surge-protected power strip with USB ports', media: ['https://m.media-amazon.com/images/I/71IngnSSNnL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/81TICXymHwL._AC_SX466_.jpg']  },
    { title: 'Cable Management Kit', description: 'Kit for organizing cables and wires', media: ['https://m.media-amazon.com/images/I/81CisjP4f9L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71WWVGguj0L._AC_SX679_.jpg']  },
    { title: 'Computer Stand', description: 'Adjustable stand for ergonomic positioning', media: ['https://m.media-amazon.com/images/I/61v9rIiuibL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71WCDoB4RAL._AC_SX679_.jpg']  },
    { title: 'Docking Station', description: 'Docking station for connecting multiple peripherals', media: ['https://m.media-amazon.com/images/I/71ja6Rb8RVL.__AC_SX300_SY300_QL70_FMwebp_.jpg', '']  },
    { title: 'Bluetooth Adapter', description: 'Bluetooth adapter for wireless connectivity', media: ['https://m.media-amazon.com/images/I/61XOqzdlatL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71vw4QK5ZZL._AC_SX466_.jpg']  },
    { title: 'Case Fans', description: 'Set of case fans for cooling', media: ['https://m.media-amazon.com/images/I/41GxkCUcXoL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81EZUdAUmtL._SX522_.jpg']  },
    { title: 'External SSD', description: '1TB external SSD for fast storage', media: ['https://m.media-amazon.com/images/I/71ifPsdG1cL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71xxr9qM0+L._AC_SX466_.jpg']  },
    { title: 'Thermal Paste Cleaner', description: 'Cleaner for removing old thermal paste', media: ['https://m.media-amazon.com/images/I/41sc6NcyxLL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81lyS4usGhL._SX522_.jpg']  },
    { title: 'BIOS Battery', description: 'Replacement battery for motherboard BIOS', media: ['https://m.media-amazon.com/images/I/81NKtOaiZ8L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71DMqZs6mIL._AC_SX466_.jpg']  },
    { title: 'CPU Thermal Pad', description: 'Thermal pad for CPU cooling', media: ['https://m.media-amazon.com/images/I/81gF0KVRAtL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81I0WjZgKYL._AC_SX466_.jpg']  },
    { title: 'Laptop Docking Station', description: 'Docking station for laptops with multiple ports', media: ['https://m.media-amazon.com/images/I/61px40J8IML.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71QU4YWT6-L._AC_SX466_.jpg']  },
    { title: 'Wireless Keyboard', description: 'Wireless keyboard with quiet keys', media: ['https://m.media-amazon.com/images/I/619brOWf-iL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71+tl1bW4fL._AC_SX466_.jpg']  },
    { title: 'Wireless Mouse', description: 'Wireless mouse with long battery life', media: ['https://m.media-amazon.com/images/I/61YQeAUIboL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71eHxfMN8fL._AC_SX466_.jpg']  },
    { title: 'Multi-Monitor Stand', description: 'Stand for holding multiple monitors', media: ['https://m.media-amazon.com/images/I/71iCbWjCopL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71h93FALh1L._AC_SX466_.jpg']  },
    { title: 'Portable Monitor', description: '15.6-inch portable monitor for on-the-go use', media: ['https://m.media-amazon.com/images/I/81F99hab1GL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71xAgLS0+nL._AC_SX679_.jpg']  },
    { title: 'USB Flash Drive', description: '32GB USB flash drive for data transfer', media: ['https://m.media-amazon.com/images/I/617BzGyQBaL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71wOd5-vLmL._AC_SX679_.jpg']  },
    { title: 'External Optical Drive', description: 'External DVD drive for laptops', media: ['https://m.media-amazon.com/images/I/71uCgaAfsUL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71Jc3qjoKeL._AC_SX679_.jpg']  },
    { title: 'Laptop Cooling Pad', description: 'Cooling pad for laptops with fans', media: ['https://m.media-amazon.com/images/I/71jUT5npz-L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81pQi2N6-XL.__AC_SX300_SY300_QL70_FMwebp_.jpg']  },
    { title: 'VR Headset', description: 'Virtual reality headset for immersive experiences', media: ['https://m.media-amazon.com/images/I/81ACdnBJ6bL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71NxybE5-gL._AC_SX466_.jpg']  },
    { title: 'Cable Sleeving Kit', description: 'Kit for customizing and organizing cables', media: ['https://m.media-amazon.com/images/I/81D6LrCwRXL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71zjuAaxWpL._AC_SX466_.jpg']  },
    { title: 'USB to Ethernet Adapter', description: 'Adapter for adding Ethernet connectivity via USB', media: ['https://m.media-amazon.com/images/I/61Bi6ElIiyL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61Cp4wnPNjL._AC_SY879_.jpg']  },
    { title: 'PCIe Expansion Card', description: 'Expansion card for additional PCIe slots', media: ['https://m.media-amazon.com/images/I/712ookJAyhL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71TWBiU7gKL._AC_SX466_.jpg']  },
    { title: 'M.2 SSD', description: '500GB M.2 SSD for ultra-fast storage', media: ['https://m.media-amazon.com/images/I/71OWtcxKgvL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/61S4fCwCigL._AC_SX466_.jpg']  },
    { title: 'Memory Card Reader', description: 'Reader for various memory card formats', media: ['https://m.media-amazon.com/images/I/71rQaE0qLfL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71uZ5LnhOOL._AC_SX466_.jpg']  },
    { title: 'PC Cleaning Kit', description: 'Kit for cleaning and maintaining your PC', media: ['https://m.media-amazon.com/images/I/61A+fuSj3FL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/71tDbvnVOxL._AC_SX466_.jpg']  },
    { title: 'Digital Pen Tablet', description: 'Tablet for digital drawing and note-taking', media: ['https://m.media-amazon.com/images/I/51-igSnkK1L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/51zN7V4as5L._AC_SX466_.jpg']  },
    { title: 'Microphone', description: 'High-quality microphone for recording and streaming', media: ['https://m.media-amazon.com/images/I/81GYqmukfcL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71OwnKTSXgL._AC_SX679_.jpg']  },
    { title: 'Laptop Case', description: 'Protective case for laptops', media: ['https://m.media-amazon.com/images/I/718QLlGmJbL._AC_SX679_.jpg', 'https://m.media-amazon.com/images/I/610cRGrWDhL._AC_SX679_.jpg']  },
    { title: 'Mouse Bungee', description: 'Bungee for managing mouse cable', media: ['https://m.media-amazon.com/images/I/81a3panfEyL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81sT12TSd5L._AC_SX466_.jpg']  },
    { title: 'Laptop Stand', description: 'Adjustable stand for laptop ergonomics', media: ['https://m.media-amazon.com/images/I/71pNZrEkYWL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/613vs1FhZLL._AC_SX466_.jpg']  },
    { title: 'Graphics Card Stand', description: 'Stand for stabilizing large graphics cards', media: ['https://m.media-amazon.com/images/I/51rOLKO0vXL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/712kCPuZZYL._AC_SX679_.jpg']  },
    { title: 'Memory Heat Spreader', description: 'Heat spreader for RAM modules', media: ['https://m.media-amazon.com/images/I/41HUxC+jZBL._SX342_SY445_.jpg', 'https://m.media-amazon.com/images/I/51qULuPrSTL._SX38_SY50_CR,0,0,38,50_.jpg']  },
    { title: 'Cooling System', description: 'Advanced cooling system for high-performance PCs', media: ['https://m.media-amazon.com/images/I/41V90Lai2wL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71ikkhgethL._SX522_.jpg']  },
    { title: 'Computer Dust Filter', description: 'Filter for keeping dust out of your PC case', media: ['https://m.media-amazon.com/images/I/51cOS6GYo2L._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81bwFor1RfL._SX522_.jpg']  },
    { title: 'USB-C Hub', description: 'Hub for expanding USB-C connectivity', media: ['https://m.media-amazon.com/images/I/61LX7fSvF7L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61Mj+9-xCxL._AC_SX466_.jpg']  },
    { title: 'KVM Switch', description: 'Switch for controlling multiple computers with one set of peripherals', media: ['https://m.media-amazon.com/images/I/41RgG1I1GNL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71HfHCpYE-L._SX522_.jpg']  },
    { title: 'Network Switch', description: 'Network switch for expanding Ethernet connections', media: ['https://m.media-amazon.com/images/I/71C646qzDnL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61QDzVMsZUL._AC_SX466_.jpg']  },
    { title: 'Power Supply Tester', description: 'Tester for checking power supply functionality', media: ['https://m.media-amazon.com/images/I/71BtwuVoqiS.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61+But47EyL._AC_SX466_.jpg']  },
    { title: 'Cable Tester', description: 'Tester for diagnosing cable issues', media: ['https://m.media-amazon.com/images/I/41CxyBH3LyL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61RH-p1dYSL._SX522_.jpg']  },
    { title: 'Replacement Laptop Battery', description: 'Battery replacement for laptops', media: ['https://m.media-amazon.com/images/I/51j23b2bAwL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71fJ1vON9EL._AC_SL1500_.jpg']  },
    { title: 'Battery Charger', description: 'Charger for rechargeable batteries', media: ['https://m.media-amazon.com/images/I/71FU+BVtZzL._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/618LTyiv0KL._AC_SX466_.jpg']  },
    { title: 'Wi-Fi Range Extender', description: 'Device for extending Wi-Fi coverage', media: ['https://m.media-amazon.com/images/I/51PrXPN16TL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/511FeVdDO8L.__AC_SX300_SY300_QL70_FMwebp_.jpg']  },
    { title: 'Bluetooth Speaker', description: 'Portable Bluetooth speaker with high sound quality', media: ['https://m.media-amazon.com/images/I/81djh1gfUwL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71xPBXerDoL._AC_SX466_.jpg']  },
    { title: 'USB Printer Cable', description: 'Cable for connecting printers via USB', media: ['https://m.media-amazon.com/images/I/61-09oVWHDL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71WNyiN0DtL._AC_SX466_.jpg']  },
    { title: 'Docking Station for Desktop', description: 'Docking station for expanding desktop connectivity', media: ['https://m.media-amazon.com/images/I/71rw1wSlfEL._AC_SX466_.jpg', 'https://m.media-amazon.com/images/I/81uUZdQ7eOL._AC_SX466_.jpg']  },
    { title: 'Power Supply Mounting Brackets', description: 'Brackets for mounting power supplies', media: ['https://m.media-amazon.com/images/I/618wJt5fY3L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61Kl8+N82XL._AC_SX679_.jpg']  },
    { title: 'Cable Management Clips', description: 'Clips for securing and organizing cables', media: ['https://m.media-amazon.com/images/I/41pFJ6eTCJL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71aVLd8eX4L._SX522_.jpg']  },
    { title: 'Fan Controller', description: 'Controller for managing case fans', media: ['https://m.media-amazon.com/images/I/41h0qQpQ5IL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/913+YdNaFhL._SX522_.jpg']  },
    { title: 'RGB Lighting Kit', description: 'Kit for adding RGB lighting to your PC', media: ['https://m.media-amazon.com/images/I/71RQQ82x17L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71hDb42FO6L._AC_SX466_.jpg']  },
    { title: 'Computer Mouse Wrist Rest', description: 'Wrist rest for mouse comfort', media: ['https://m.media-amazon.com/images/I/711-BWJhMKL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71h6WHniqjL._AC_SX466_.jpg']  },
    { title: 'Gaming Chair', description: 'Ergonomic chair designed for gamers', media: ['https://m.media-amazon.com/images/I/61t4mpabO+L._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/61DrC-6iAIL._AC_SX679_.jpg']  },
    { title: 'Desktop Organizer', description: 'Organizer for keeping your desk tidy', media: ['https://m.media-amazon.com/images/I/815HwI2Jm6L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81wjV+0VAQL._AC_SX679_.jpg']  },
    { title: 'Cable Tie Kit', description: 'Kit of cable ties for securing wires', media: ['https://m.media-amazon.com/images/I/81cJhkeKJ7L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/41GhqYdfHMS._AC_.jpg']  },
    { title: 'Power Cable', description: 'Replacement power cable for PCs', media: ['https://m.media-amazon.com/images/I/710PghR1a1L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81uss2Bh8vL._AC_SX466_.jpg']  },
    { title: 'HDMI Cable', description: 'High-speed HDMI cable for video and audio', media: ['https://m.media-amazon.com/images/I/81rW1c3meNL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71xA987xm2L._AC_SX466_.jpg']  },
    { title: 'DisplayPort Cable', description: 'Cable for connecting monitors via DisplayPort', media: ['https://m.media-amazon.com/images/I/81W0FA5T5+L._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/41NhBQZl2OL._AC_US40_.jpg']  },
    { title: 'VGA Cable', description: 'Cable for connecting monitors via VGA', media: ['https://m.media-amazon.com/images/I/71ZdXCcsoAL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61Ed5g6AdFL._AC_SX466_.jpg']  },
    { title: 'DVI Cable', description: 'Cable for connecting monitors via DVI', media: ['https://m.media-amazon.com/images/I/71tl9d7vdJL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71tCaDq3H6L._AC_SX679_.jpg']  },
    { title: 'Adapter for HDMI to VGA', description: 'Adapter for converting HDMI to VGA', media: ['https://m.media-amazon.com/images/I/71nKG2w6ENL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61CzG7kfhRL._AC_SX466_.jpg']  },
    { title: 'Adapter for USB to HDMI', description: 'Adapter for connecting USB to HDMI', media: ['https://m.media-amazon.com/images/I/61Pxn1-kWTL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71b9qveySeL._AC_SX466_.jpg']  },
    { title: 'Keyboard Cover', description: 'Cover to protect your keyboard from dust and spills', media: ['https://m.media-amazon.com/images/I/71qtaC-6EwL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61XNCpiSDYL._AC_SX466_.jpg']  },
    { title: 'Laptop Screen Protector', description: 'Protector for preventing scratches on laptop screens', media: ['https://m.media-amazon.com/images/I/61kkCL0bGYL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61wyV6kL4ZL._AC_SX679_.jpg']  },
    { title: 'Screen Cleaning Kit', description: 'Kit for cleaning computer screens', media: ['https://m.media-amazon.com/images/I/81bvFMXhZNL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71ym19qnvtL._AC_SX466_.jpg']  },
    { title: 'Portable Power Bank', description: 'Power bank for charging devices on the go', media: ['https://m.media-amazon.com/images/I/717HQR60pZL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71in6hzatKL._AC_SX466_.jpg']  },
    { title: 'Multi-Port Charger', description: 'Charger with multiple ports for simultaneous device charging', media: ['https://m.media-amazon.com/images/I/51Z8hS3IupL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71ovAVjvhbL._AC_SX466_.jpg']  },
    { title: 'Wireless Charging Pad', description: 'Pad for charging devices wirelessly', media: ['https://m.media-amazon.com/images/I/61oIAKY9s1L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/517G72RjeiL._AC_SX679_.jpg']  },
    { title: 'USB Hub with SD Card Reader', description: 'USB hub with integrated SD card reader', media: ['https://m.media-amazon.com/images/I/61huiyXXuYL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71qut0y6J7L._AC_SX466_.jpg'] },
    { title: 'Laptop Cooling Stand', description: 'Stand with built-in cooling fans for laptops', media: ['https://m.media-amazon.com/images/I/615Vqa3Hc2L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71ilHh+RM4L._AC_SX466_.jpg'] },
    { title: 'Desk Lamp', description: 'Adjustable desk lamp with LED light', media: ['https://m.media-amazon.com/images/I/71aQ5a5rxKL.__AC_SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71W4N1FkfUL._AC_SX522_.jpg'] },
    { title: 'Cable Management Sleeve', description: 'Sleeve for bundling and organizing cables', media: ['https://m.media-amazon.com/images/I/51PEwCRekpL.__AC_SY300_SX300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61xoY7Erq7S._AC_SX466_.jpg'] },
    { title: 'Bluetooth Keyboard', description: 'Bluetooth keyboard for wireless typing', media: ['https://m.media-amazon.com/images/I/71a7eCZjymL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/718v4H8gD-L._AC_SX466_.jpg'] },
    { title: 'Bluetooth Mouse', description: 'Bluetooth mouse for wireless use', media: ['https://m.media-amazon.com/images/I/41FwDnfOf9L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61gzJOPN6lL._AC_SX466_.jpg'] },
    { title: 'Computer Repair Tool Kit', description: 'Kit with tools for repairing computers', media: ['https://m.media-amazon.com/images/I/81sLcXPAy8L.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71e3ccgA2UL._AC_SX679_.jpg'] },
    { title: 'Anti-Static Wrist Strap', description: 'Wrist strap for preventing static discharge', media: ['https://m.media-amazon.com/images/I/41smi1ALjZL._SY445_SX342_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/61XjoSRTVUL._SX522_.jpg'] },
    { title: 'Heat Gun', description: 'Heat gun for various repair and crafting tasks', media: ['https://m.media-amazon.com/images/I/715ryek5TzL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/71TyDOj6jQL._AC_SX679_.jpg'] },
    { title: 'Screwdriver Set with Magnetic Tips', description: 'Magnetic screwdriver set for easy handling', media: ['https://m.media-amazon.com/images/I/81+jq46RN9L._AC_SY300_SX300_.jpg', 'https://m.media-amazon.com/images/I/81Cx5YzbN3L._AC_SX679_.jpg'] },
    { title: 'Precision Tool Kit', description: 'Precision tools for detailed work on electronics', media: ['https://m.media-amazon.com/images/I/81casfLwHNL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/91QfHEmLjrL._AC_SX679_.jpg'] },
    { title: 'Electric Soldering Iron', description: 'Soldering iron for electronics repairs', media: ['https://m.media-amazon.com/images/I/71ewMXnqRyL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/81TdkC1qHKL._AC_SX679_.jpg'] },
    { title: 'Desoldering Pump', description: 'Pump for removing solder', media: ['https://m.media-amazon.com/images/I/61lGE4qnkpL.__AC_SX300_SY300_QL70_FMwebp_.jpg', 'https://m.media-amazon.com/images/I/611NOb7LftL._AC_SX679_.jpg'] }
  ]
}

# Define the date range for April
april_range = (Date.new(2024, 4, 1)..Date.new(2024, 4, 30))

# Seed ads with sellers restricted to their categories
category_ads.each do |category_name, ads|
  # Find the category by name
  category = Category.find_by(name: category_name)
  next unless category
  
  # Fetch all subcategories for this category
  subcategories = category.subcategories
  subcategory_count = subcategories.count

  # Initialize a counter to track subcategory assignment
  subcategory_index = 0
  
  eligible_sellers = Seller.joins("INNER JOIN categories_sellers ON categories_sellers.seller_id = sellers.id")
                         .where(categories_sellers: { category_id: category.id })

  ads.each do |ad_data|
    if eligible_sellers.empty?
      puts "No sellers available in category: #{category.name} to assign to this ad: #{ad_data[:title]}. Skipping ad."
      next
    end
    
    # Select a random seller from eligible sellers
    seller = eligible_sellers.sample
    
    # Assign the subcategory in a round-robin manner
    assigned_subcategory = subcategories[subcategory_index]
  
    # Update the index, looping back to the start if necessary
    subcategory_index = (subcategory_index + 1) % subcategory_count
  
    # Find or create the ad
    ad = Ad.find_or_initialize_by(title: ad_data[:title])
  
    if ad.new_record?
      # Generate a random date in April
      created_at = Faker::Date.between(from: april_range.begin, to: april_range.end)
  
      ad.description = ad_data[:description]
      ad.category_id = category.id
      ad.subcategory_id = assigned_subcategory.id if assigned_subcategory.present?
      ad.seller_id = seller.id # Assign seller_id from the eligible seller
      ad.price = Faker::Commerce.price(range: 200..10000)
      ad.quantity = Faker::Number.between(from: 30, to: 100)
      ad.brand = Faker::Company.name
      ad.manufacturer = Faker::Company.name
      ad.item_length = Faker::Number.between(from: 10, to: 50)
      ad.item_width = Faker::Number.between(from: 10, to: 50)
      ad.item_height = Faker::Number.between(from: 10, to: 50)
      ad.item_weight = Faker::Number.decimal(l_digits: 1, r_digits: 2)
      ad.weight_unit = ['Grams', 'Kilograms'].sample
      ad.condition = [:brand_new, :second_hand].sample
      ad.media = ad_data[:media]
      ad.created_at = created_at
      ad.updated_at = created_at
      ad.save!
      puts "Ad created for Seller ID: #{seller.id}, Ad Title: #{ad.title}"
    else
      puts "Ad already exists: #{ad.title}. Skipping ad."
    end
  end
end


puts "Starts seeding the orders"



# Define the date range for each month
date_ranges = {
  August: (Date.new(2024, 8, 1)..Date.new(2024, 8, 31)),
  September: (Date.new(2024, 9, 1)..Date.new(2024, 9, 30)),
  October: (Date.new(2024, 10, 1)..Date.new(2024, 10, 31)),
  November: (Date.new(2024, 11, 1)..Date.today) # Up to the current date
}

# MPesa tariff calculation
def calculate_transaction_fee(amount)
  case amount
  when 1..49 then 0
  when 50..100 then 0
  when 101..500 then 7
  when 501..1000 then 13
  when 1001..1500 then 23
  when 1501..2500 then 33
  when 2501..3500 then 53
  when 3501..5000 then 57
  when 5001..7500 then 78
  when 7501..10000 then 90
  when 10001..15000 then 100
  when 15001..20000 then 105
  when 20001..250000 then 108
  else 0
  end
end

def generate_mpesa_transaction_code
  alpha_part = Faker::Alphanumeric.unique.alpha(number: 7).upcase
  random_digits = Faker::Number.number(digits: 3)
  unique_part = Faker::Alphanumeric.unique.alpha(number: 3).upcase
  "#{alpha_part[0..1]}#{random_digits}#{alpha_part[2..-1]}#{unique_part}"
end
DELIVERY_FEE = 150

# Generate order data
order_data = 100.times.map do
  buyer = Buyer.all.sample
  status = ['Processing', 'Dispatched', 'In-Transit', 'Delivered', 'Cancelled', 'Returned'].sample
  
  # Create order items first to calculate fees
  order_items = rand(1..5).times.map do
    ad = Ad.all.sample
    quantity = Faker::Number.between(from: 1, to: 10)
    price = ad.price
    total_price = price * quantity

    # Calculate processing fee for this specific ad's total
    ad_processing_fee = calculate_transaction_fee(total_price).round(2) * 2

    {
      ad_id: ad.id,
      quantity: quantity,
      price: price.round(2),                     # Round price to two decimal places
      total_price: total_price.round(2),         # Round total price to two decimal places
      processing_fee: ad_processing_fee,    # Store processing fee per ad
      seller_id: ad.seller_id
    }
  end

  # Calculate subtotal from order items
  subtotal = order_items.sum { |item| item[:total_price] }
  
  # Sum all processing fees from individual ads
  total_processing_fee = order_items.sum { |item| item[:processing_fee] }
  
  # Calculate total amount including all fees
  total_amount = (subtotal + total_processing_fee + DELIVERY_FEE).round(2) # Ensure two decimal precision

  # Generate random created_at date
  selected_month = date_ranges.keys.sample
  date_range = date_ranges[selected_month]
  created_at = Faker::Date.between(from: date_range.begin, to: date_range.end)

  # Return the order data
  {
    buyer_id: buyer.id,
    status: status,
    processing_fee: total_processing_fee.round(2),  # Round total processing fee
    delivery_fee: DELIVERY_FEE,                    # Fixed delivery fee
    total_amount: total_amount,                    # Total amount including all fees
    mpesa_transaction_code: generate_mpesa_transaction_code,
    created_at: created_at,
    updated_at: created_at,
    order_items: order_items
  }
end


# Sort order data by created_at date
sorted_order_data = order_data.sort_by { |data| data[:created_at] }

# Create orders in sorted order with all associations
sorted_order_data.each do |data|
  # Create the order with all fees
  order = Order.create!(
    buyer_id: data[:buyer_id],
    status: data[:status],
    processing_fee: data[:processing_fee],    # Total processing fee from all ads
    delivery_fee: data[:delivery_fee],        # Fixed delivery fee
    total_amount: data[:total_amount],
    mpesa_transaction_code: data[:mpesa_transaction_code],
    created_at: data[:created_at],
    updated_at: data[:updated_at]
  )

  # Track unique sellers for this order
  order_sellers = Set.new

  # Create order items and collect unique sellers
  data[:order_items].each do |item_data|
    OrderItem.create!(
      order_id: order.id,
      ad_id: item_data[:ad_id],
      quantity: item_data[:quantity],
      price: item_data[:price],
      total_price: item_data[:total_price],
      created_at: data[:created_at],
      updated_at: data[:updated_at]
    )

    # Add seller to set of unique sellers
    order_sellers.add(item_data[:seller_id])
  end

  # Create OrderSeller associations for unique sellers only
  order_sellers.each do |seller_id|
    OrderSeller.create!(
      order_id: order.id,
      seller_id: seller_id,
      created_at: data[:created_at],
      updated_at: data[:updated_at]
    )
  end
end


puts "Starts seeding for the ad reviews"

# Fetch all buyer and ad IDs
buyers = Buyer.pluck(:id)
ads = Ad.pluck(:id)

puts "Seeding click_events and wish_lists..."

# Click Events and Wish Lists seeding logic
buyers.each do |buyer_id|
  num_ads = rand(20..50)
  ad_sample = ads.sample(num_ads)

  ad_sample.each do |ad_id|
    num_clicks = rand(1..5)

    num_clicks.times do
      created_at_time = Faker::Time.between(from: 5.months.ago, to: Time.current)
      click_event_time = Faker::Time.between(from: 5.months.ago, to: Time.current)

      # Create Click Event
      ClickEvent.create!(
        buyer_id: buyer_id,
        ad_id: ad_id,
        event_type: "Ad-Click",
        metadata: nil,
        created_at: click_event_time,
        updated_at: click_event_time
      )

      # Create Add-to-Wish-List Event
      ClickEvent.create!(
        buyer_id: buyer_id,
        ad_id: ad_id,
        event_type: "Add-to-Wish-List",
        metadata: nil,
        created_at: created_at_time,
        updated_at: created_at_time
      )

      # Create Reveal-Seller-Details Event
      ClickEvent.create!(
        buyer_id: buyer_id,
        ad_id: ad_id,
        event_type: "Reveal-Seller-Details",
        metadata: nil,
        created_at: click_event_time,
        updated_at: click_event_time
      )

      # Create WishList entry ONLY IF it doesn't already exist
      WishList.find_or_create_by!(
        buyer_id: buyer_id,
        ad_id: ad_id
      ) do |wishlist|
        wishlist.created_at = created_at_time
        wishlist.updated_at = created_at_time
      end
    end
  end
end

puts "Seeding completed successfully!"

# Generate 20 reviews for each ad
Ad.all.each do |ad|
  10.times do
    buyer = Buyer.all.sample
    rating = Faker::Number.between(from: 1, to: 5)
    review_text = Faker::Lorem.sentence(word_count: Faker::Number.between(from: 5, to: 10))

    Review.create!(
      ad_id: ad.id,
      buyer_id: buyer.id,
      rating: rating,
      review: review_text
    )
  end
end

puts "Starts seeding for the FAQs"

# Clear existing records
Faq.delete_all

# Create FAQs
50.times do
  Faq.create!(
    question: Faker::Lorem.sentence(word_count: 6),
    answer: Faker::Lorem.paragraph(sentence_count: 2)
  )
end

puts "Starts seeding for the About"

# Clear existing records
About.delete_all

# Create About entry with Faker data
About.create!(
  description: Faker::Lorem.paragraph(sentence_count: 3),
  mission: Faker::Lorem.sentence(word_count: 12),
  vision: Faker::Lorem.sentence(word_count: 12),
  values: Faker::Lorem.words(number: 5),  # Random list of 5 words
  why_choose_us: Faker::Lorem.paragraph(sentence_count: 2),
  image_url: Faker::LoremFlickr.image(size: "600x400", search_terms: ['business'])
)

puts "Starts seeding for the Conversations"

require 'faker'

admin = Admin.find_by(email: 'admin@example.com')
buyers = Buyer.all
sellers = Seller.all
ads = Ad.all  # Assuming ads exist

raise 'Admin not found' unless admin

# Helper to create messages
def create_messages(conversation, sender, receiver)
  10.times do |i|
    Message.create!(
      conversation: conversation,
      sender: sender,
      content: Faker::Lorem.sentence(word_count: 8 + i)
    )
    Message.create!(
      conversation: conversation,
      sender: receiver,
      content: Faker::Lorem.sentence(word_count: 8 + i)
    )
  end
end

# Create admin ↔ buyer conversations
buyers.each do |buyer|
  convo = Conversation.find_or_create_by!(admin_id: admin.id, buyer_id: buyer.id)
  create_messages(convo, admin, buyer)
end

# Create admin ↔ seller conversations
sellers.each do |seller|
  convo = Conversation.find_or_create_by!(admin_id: admin.id, seller_id: seller.id)
  create_messages(convo, admin, seller)
end

# Create buyer ↔ seller ↔ ad conversations
# Each buyer can message only once per ad
buyers.first(5).each do |buyer|
  ads.sample(10).each do |ad|
    next if ad.seller.nil?

    seller = ad.seller

    # Skip if a conversation already exists for this buyer and ad
    existing_convo = Conversation.find_by(buyer_id: buyer.id, ad_id: ad.id)
    next if existing_convo.present?

    convo = Conversation.create!(
      buyer_id: buyer.id,
      seller_id: seller.id,
      ad_id: ad.id
    )

    create_messages(convo, buyer, seller)
  end
end

puts "✅ Seeded conversations and messages successfully."

puts "Starts seeding for the Banners"

# Create banner records with local banner images
banner_urls = [
  "http://localhost:3002/static/media/banner-01.jpg",
  "http://localhost:3002/static/media/banner-02.jpg", 
  "http://localhost:3002/static/media/banner-03.jpg",
  "http://localhost:3002/static/media/banner-04.jpg",
  "http://localhost:3002/static/media/banner-05.jpg"
]

banner_urls.each_with_index do |url, index|
  Banner.find_or_create_by!(image_url: url) do |banner|
    puts "Created banner #{index + 1}"
  end
end

puts "✅ Seeded banners successfully."

puts "Starts seeding for the Promotions"

# Function to generate a random coupon code with the discount percentage
def generate_coupon_code(discount_percentage)
  random_string = Faker::Alphanumeric.alpha(number: 4).upcase
  "#{random_string}#{discount_percentage.to_s.rjust(2, '0')}"
end

# Define holiday-related promotion titles in Kenya
holiday_titles = [
  "Back to School Bonanza",
  "Easter Weekend Sale",
  "Madaraka Day Discounts",
  "Jamhuri Day Specials",
  "Christmas Mega Sale",
  "New Year Offers",
  "Black Friday Deals",
  "Cyber Monday Discounts",
  "Ramadan Kareem Offers",
  "Mashujaa Day Bargains"
]

# Create 10 promotions with random data
10.times do
  discount_percentage = rand(1..14) # Random percentage between 1 and 14
  Promotion.create!(
    title: holiday_titles.sample,
    description: Faker::Lorem.sentence,
    discount_percentage: discount_percentage,
    coupon_code: generate_coupon_code(discount_percentage),
    start_date: Faker::Date.backward(days: 0),
    end_date: Faker::Date.forward(days: rand(10..20))
  )
end

puts 'Congratulations!! Seed data created successfully!'

# Load internal user exclusions
load Rails.root.join('db', 'seeds', 'internal_user_exclusions.rb')