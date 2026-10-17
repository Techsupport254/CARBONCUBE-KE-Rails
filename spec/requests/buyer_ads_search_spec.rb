require 'rails_helper'

RSpec.describe 'Buyer Ads Search', type: :request do
  let(:category) { Category.create!(name: 'Tools & Hardware') }
  let(:subcategory) { Subcategory.create!(name: 'Hand Tools', category_id: category.id) }

  def create_seller(enterprise_name:, uid:)
    Seller.create!(
      fullname: enterprise_name,
      email: "#{uid}@example.com",
      enterprise_name: enterprise_name,
      provider: 'google',
      uid: uid
    )
  end

  def create_ad(seller:, title:)
    seller.ads.create!(
      title: title,
      description: 'Quality item for sale',
      price: 100,
      brand: 'TestBrand',
      manufacturer: 'TestMfg',
      category: category,
      subcategory: subcategory,
      condition: 'brand_new',
      weight_unit: 'Grams',
      media: ['https://example.com/img.jpg']
    )
  end

  def search_ads(query)
    get '/buyer/ads/search', params: { query: query }
    expect(response).to have_http_status(:ok)
    response.parsed_body['ads']
  end

  describe 'shop name matching' do
    let!(:pangu) { create_seller(enterprise_name: 'Pangu Hardware', uid: 'pangu-uid') }
    let!(:cath) { create_seller(enterprise_name: 'Cath Mash Technologies', uid: 'cath-uid') }

    it 'returns the products of a shop whose full name is searched' do
      create_ad(seller: pangu, title: 'Heavy Duty Wrench')
      create_ad(seller: pangu, title: 'Pipe Wrench 18in')

      ads = search_ads('Pangu Hardware')

      expect(ads).not_to be_empty
      expect(ads.map { |ad| ad['enterprise_name'] }).to all(eq('Pangu Hardware'))
    end

    it 'matches a distinctive partial shop-name token' do
      create_ad(seller: pangu, title: 'Ball Bearing Set')

      ads = search_ads('pangu')

      expect(ads).not_to be_empty
      expect(ads.map { |ad| ad['enterprise_name'] }).to all(eq('Pangu Hardware'))
    end

    it 'matches a multi-word subset of the shop name' do
      create_ad(seller: cath, title: 'Smartphone X10')

      ads = search_ads('cath mash')

      expect(ads.map { |ad| ad['enterprise_name'] }).to include('Cath Mash Technologies')
    end

    it 'matches case-insensitively and ignores punctuation' do
      create_ad(seller: pangu, title: 'Claw Hammer')

      ads = search_ads('PANGU, hardware!!')

      expect(ads.map { |ad| ad['enterprise_name'] }).to include('Pangu Hardware')
    end

    it 'tolerates small typos in the shop name' do
      create_ad(seller: pangu, title: 'Bench Vise')

      ads = search_ads('panguu')

      expect(ads.map { |ad| ad['enterprise_name'] }).to include('Pangu Hardware')
    end

    it 'ranks the matched shop products at the top of the results' do
      create_ad(seller: pangu, title: 'Hex Bolt M8')
      rival = create_seller(enterprise_name: 'Rival Tools Mart', uid: 'rival-uid')
      create_ad(seller: rival, title: 'Pangu Special Drill')

      ads = search_ads('pangu')

      expect(ads.first['enterprise_name']).to eq('Pangu Hardware')
    end

    it 'does not leak unrelated shop products into a shop-name query' do
      create_ad(seller: pangu, title: 'Pliers Set')
      other = create_seller(enterprise_name: 'Zed Wholesalers', uid: 'zed-uid')
      create_ad(seller: other, title: 'Garden Hose Reel')

      ads = search_ads('pangu')

      expect(ads.map { |ad| ad['enterprise_name'] }).not_to include('Zed Wholesalers')
    end
  end

  describe 'generic token guard' do
    it 'does not flood results with shops matching only generic name tokens' do
      generic_shop = create_seller(enterprise_name: 'Nairobi Hardware Supplies', uid: 'nhs-uid')
      create_ad(seller: generic_shop, title: 'Adjustable Spanner')

      ads = search_ads('hardware')

      expect(ads.map { |ad| ad['enterprise_name'] }).not_to include('Nairobi Hardware Supplies')
    end
  end

  describe 'product search regression' do
    it 'still returns plain title matches for product queries' do
      seller = create_seller(enterprise_name: 'Rival Tools Mart', uid: 'rival-uid')
      create_ad(seller: seller, title: 'Cordless Angle Grinder')

      ads = search_ads('cordless angle grinder')

      expect(ads.map { |ad| ad['title'] }).to include('Cordless Angle Grinder')
    end
  end

  describe 'small seller visibility & anti-clumping' do
    let!(:big_seller) { create_seller(enterprise_name: 'Mega Tool Depot', uid: 'mega-uid') }
    let!(:small_seller) { create_seller(enterprise_name: 'Solo Craft Tools', uid: 'solo-uid') }

    it 'prevents a single seller from monopolizing the top results slate (anti-clumping)' do
      # Big seller lists 4 wrenches
      4.times { |i| create_ad(seller: big_seller, title: "Torque Wrench Pro #{i}") }
      # Small seller lists 1 wrench
      create_ad(seller: small_seller, title: 'Torque Wrench Essential')

      ads = search_ads('torque wrench')

      # The top 3 should not be all 3 from big seller; small seller should appear in top 3
      top_sellers = ads.first(3).map { |ad| ad['enterprise_name'] }
      expect(top_sellers).to include('Solo Craft Tools')
      expect(top_sellers.count('Mega Tool Depot')).to be <= 2
    end

    it 'promotes responsive sellers with complete listings over inactive sparse listings' do
      responsive_seller = create_seller(enterprise_name: 'Responsive Tech', uid: 'resp-uid')
      responsive_seller.update!(last_active_at: 10.minutes.ago)

      inactive_seller = create_seller(enterprise_name: 'Inactive Depot', uid: 'inact-uid')
      inactive_seller.update!(last_active_at: 30.days.ago)

      # Responsive seller has complete listing: 4 photos, specs, description >= 100 chars
      ad_complete = responsive_seller.ads.create!(
        title: 'Impact Driver Kit',
        description: 'Comprehensive heavy-duty impact driver with brushless motor and dual lithium-ion batteries included for pro work.',
        price: 250,
        brand: 'DeWalt',
        manufacturer: 'Stanley',
        category: category,
        subcategory: subcategory,
        condition: 'brand_new',
        weight_unit: 'Grams',
        media: ['https://example.com/1.jpg', 'https://example.com/2.jpg', 'https://example.com/3.jpg', 'https://example.com/4.jpg'],
        specifications: { 'voltage' => '20V', 'torque' => '200Nm' }
      )

      # Inactive seller has bare listing: 1 photo, short description, no specs
      ad_bare = inactive_seller.ads.create!(
        title: 'Impact Driver Kit',
        description: 'Just driver',
        price: 250,
        brand: 'DeWalt',
        manufacturer: 'Stanley',
        category: category,
        subcategory: subcategory,
        condition: 'brand_new',
        weight_unit: 'Grams',
        media: ['https://example.com/1.jpg']
      )

      ads = search_ads('Impact Driver Kit')

      expect(ads.first['enterprise_name']).to eq('Responsive Tech')
    end

    it 'reserves exploration slots for relevant small sellers when paid merchants fill the top positions' do
      # Big seller has 10 items
      10.times { |i| create_ad(seller: big_seller, title: "Precision Screwdriver Set #{i}") }
      # Small seller has 1 item
      create_ad(seller: small_seller, title: 'Precision Screwdriver Set Basic')

      ads = search_ads('precision screwdriver set')

      # Small seller should appear within the first 4 slots due to exploration / anti-clumping
      top_4_sellers = ads.first(4).map { |ad| ad['enterprise_name'] }
      expect(top_4_sellers).to include('Solo Craft Tools')
    end
  end
end
